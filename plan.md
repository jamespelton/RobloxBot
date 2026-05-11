# Deep Brainstorm Pipeline
---

## Instructions

This workflow runs a direct multi-model brainstorm pipeline:

1. **Question preparation in the main workflow** — you assess complexity, choose the number of brainstormers (`N`, default `3`, max `5`), and prepare context if relevant.
2. **Direct worker fan-out** — you spawn `N` `zenflow-brainstormer` subagents in parallel (no intermediary orchestrator subagent).
3. **Per-worker clarification loop** — if any individual brainstormer asks a clarifying question, relay it to the user, then resume only that brainstormer.
4. **Cross-model synthesis** — you read all reports, cross-reference recommendations, resolve disagreements, and write a consolidated best recommendation.
5. **Report review gate** — you present the final brainstorm report to the user so they can inspect it and ask follow-up questions.
6. **Follow-up loop** — if the user asks follow-up questions, you either clarify directly in the main workflow or run another multi-model follow-up pass, then update the report and present it again.

You are the top-level agent and the only orchestrator in this workflow.

This is a standalone work task — no git repository and no project source tree by default. Work in chat and files under `{@artifacts_path}`. If the user provides attachments or concrete local files, treat those as context; otherwise skip repository-style codebase exploration.

The value comes from model diversity. Different models independently research and reason about the same problem, surfacing different options and trade-offs. You must identify where models agree (high confidence) and where they disagree (needs deeper analysis).

The required skills are pre-installed; you have rights to use them.

When passing file paths to subagents, use FULL absolute paths inside `{@artifacts_path}`. Do NOT use `~` or `$HOME` — subagents will not expand them.

When calling `spawn_subagent`, on the initial spawn you MUST pass all files the subagent needs at startup (plans, reports, reviews) via the `attachedFiles` parameter (an array of absolute paths). Do NOT embed file contents in the prompt — the subagent will read attached files automatically. Reference the files by path in the prompt so the subagent knows what each one is for.
On resume, if the subagent needs to read any file that is new since the initial spawn, or any file whose content has changed, pass those file paths via `attachedFiles` on the resume call as well. Reference each attached file by path in the resume prompt and instruct the subagent to re-read it. Files already attached at spawn that have not changed do not need to be re-attached.

This workflow does **not** create a separate plan artifact. The canonical artifact for final review and follow-up questions is `{@artifacts_path}/brainstorm_report.md`.

---

**Artifact paths** (resolve `{@artifacts_path}` to its absolute form before passing to subagents):

- Brainstormer report pattern: `{@artifacts_path}/brainstormer_<index>_report.md`
- Default brainstormer report files:
  - `{@artifacts_path}/brainstormer_1_report.md`
  - `{@artifacts_path}/brainstormer_2_report.md`
  - `{@artifacts_path}/brainstormer_3_report.md`
- Final brainstorm report: `{@artifacts_path}/brainstorm_report.md`
- Follow-up worker output pattern: `{@artifacts_path}/brainstorm_followup_<round>_<index>.md` (`<index>` is the 1-based brainstormer index from Phase 1, so the worker assigned `selected_models[0]` writes to `brainstorm_followup_<round>_1.md`)
- Optional follow-up scratch summary: `{@artifacts_path}/brainstorm_followup_<round>_summary.md`

---

## Determine Number of Brainstormers

Decide `N` and model assignments before spawning any workers.

**Model defaults**: The model IDs listed in this workflow are *suggested defaults*. If the user asks for specific models, honor that override. If a listed model is unavailable, substitute the most-capable available alternative for the same role or perspective and continue — do not fail.

1. First, check whether the user explicitly named the models they want to use.
   - Examples: "use Opus + Gemini + GPT", "use only Claude and GPT", "run this with sonnet-4-6-think and gpt-5-5".
   - If the user explicitly specifies model(s), honor that request instead of the default rotation.
   - Preserve the user's requested order when it is clear.
   - Do **not** cap the model list when the user explicitly provides it.
   - If the user specifies model names ambiguously or names no valid available models, ask a clarifying question before spawning workers.
2. If the user did **not** specify models, use the big 3 by default:
   - `opus-4-7-think`
   - `gpt-5-5`
   - `gemini-3-1-pro-preview`
3. If the user explicitly requested more model perspectives or a larger worker count without naming exact models (examples: "use 5 brainstormers", "more model perspectives", "4 different models"), honor it up to a maximum of `5` by extending beyond the default 3.
4. If the user did **not** specify exact models, keep `N` in range `[3, 5]`.
5. Complexity scaling is secondary in this workflow because all workers receive the same question; the main reason to increase `N` is to add model diversity.

Extended rotation pool when the user wants more than the default big 3 without naming exact models:

1. `opus-4-7-think`
2. `gpt-5-5`
3. `gemini-3-1-pro-preview`
4. `gpt-5-4`
5. `opus-4-6-think`

Model assignment rules:

- If the user explicitly specified models, set `selected_models` to those requested valid models and set `N = len(selected_models)`.
- Otherwise, set `selected_models` to the first `N` entries from the extended rotation pool, which means the default run uses the big 3.
- For brainstormer `i` (1-based), assign `model = selected_models[i - 1]`. Example: `brainstormer_1_report.md` corresponds to `selected_models[0]`.

For brainstormer `i`, assign report path:

- `{@artifacts_path}/brainstormer_i_report.md`

Reuse the same `N` and model assignments for any large follow-up pass unless the user explicitly asks for a different number of models or a different model list.

---

## Prepare Question

Before spawning workers:

1. Determine whether the question depends on any provided local files, attachments, or other concrete workspace context.
   - If yes, inspect the relevant files using Read/Grep/Glob and include concrete context in the prompt.
   - If no, skip local file exploration.
2. If the question is ambiguous or underspecified, ask clarifying questions to the user and wait for answers before spawning workers.
3. Formulate one worker prompt using the user's question plus any relevant context.
4. Use the identical worker prompt for all workers.

---

## Spawn N Brainstormers in Parallel

Spawn exactly one `zenflow-brainstormer` subagent per worker.

For each brainstormer `i` in `1..N`, call `spawn_subagent` with:

- model: assigned model for brainstormer `i`
- skill: `zenflow-brainstormer`
- prompt:
  > 
  > Question: <the user's question, verbatim>
  > Context (if applicable): <context_or_none>
  > Output path: `{@artifacts_path}/brainstormer_i_report.md`

Spawn all workers in parallel and store each session ID.

---

## Await All Brainstormers and Read Reports

For each brainstormer `i`:

1. Await completion using the saved session ID.
2. If the brainstormer asks clarifying question(s):
   - Relay the question(s) to the user verbatim.
     - If another brainstormer had already asked the same question, don't ask the user - answer the subagent by yourself.
   - Resume only that brainstormer with:
     > The user answered your questions:
     >
     > USER RESPONSE: <paste the user's answer verbatim>
     >
     > Continue brainstorming and write your report to `{@artifacts_path}/brainstormer_i_report.md`.
   - Await that brainstormer again.
3. Read `{@artifacts_path}/brainstormer_i_report.md`.
4. If file is missing or empty, resume that same brainstormer once with:
   > Your previous response did not write a valid report file at `{@artifacts_path}/brainstormer_i_report.md`.
   > You MUST call the Write tool now with your brainstorm report.
   > Respond with a single Write tool call only.
5. Re-read the file after resume. If still missing/empty, mark brainstormer `i` as failed.

It would be wise to wait for all subagents and make only one round with many questions (some of them probably would duplicate each other - merge similar questions), rather than multiple rounds with a few questions. 

Proceed with synthesis if at least one report file is valid.

If **all** report files are missing/invalid after one retry each:

1. Perform in-band research and brainstorming yourself (at least 5 distinct web queries).
2. Build a full report with citations and recommendation.
3. Write directly to `{@artifacts_path}/brainstorm_report.md`.
4. Skip synthesis sub-steps that depend on worker files.

---

## Cross-Model Synthesis Final Report

When at least one report file is valid:

1. Read all valid report files.
2. Identify consensus:
   - Options or recommendations independently supported by multiple models are higher-confidence signals.
3. Identify disagreements:
   - Analyze conflicting recommendations and compare reasoning quality and evidence strength.
4. Surface unique insights:
   - Evaluate useful ideas/risks identified by only one model and include valid additions.
5. If models present conflicting evidence, resolve using authority order:
   - official docs > benchmarks > community experience > blog posts.
6. Combine the best elements:
   - One report may provide the strongest core recommendation while another contributes critical risk mitigation or creative enhancement.
7. If a significant conflict blocks recommendation quality, ask the user a targeted clarifying question, then finalize.
8. Write the final consolidated report to `{@artifacts_path}/brainstorm_report.md`.

Try to keep the report informative and nice. Do NOT reference model names or worker numbers in the final report. Present a single coherent voice.
---

## Review the Report — Gate, STOP HERE

After `{@artifacts_path}/brainstorm_report.md` is written:

1. Read `{@artifacts_path}/brainstorm_report.md`.

2. Prefer calling the `ask_artifact_review` MCP tool with:
   - `file_path`: absolute path to `{@artifacts_path}/brainstorm_report.md`

   This tool renders the artifact in a rich UI where the user can read the full file, add comments, and choose an action. The tool **blocks** until the user responds.

   If the user declines the tool, or if the tool is unavailable/fails, fall back to plain text: ask the user to review `{@artifacts_path}/brainstorm_report.md` directly and reply with either `Proceed`, `Continue with comments`, `Address changes`, or `Cancel`, plus any optional comments. If they reply in free text instead of using those exact labels, infer the closest action from their message.

3. Interpret the review result from either path:
   - **Tool path**: `answers[0].selected` contains the action and `answers[1].custom_answer` contains free-text feedback (may be empty).
   - **Plain-text fallback**: treat the user's message as the action source and preserve the rest of their message as feedback when relevant.
   - Action handling:
     - `"Proceed"` → go to **Present Final Result**.
     - `"Continue with comments"` → go to **Present Final Result**; note the user's comments for awareness (no rework needed).
     - `"Address changes"` → the user wants modifications or has follow-up questions. Use their feedback as the user's comment and enter the **Follow-Up Loop After Report Review** below.
     - `"Cancel"` → post `Pipeline aborted after report review by user request.` and stop. Pipeline complete.

4. If the selected action is `"Address changes"` but the user's feedback is empty, finish the workflow (treat as Proceed).

---

## Follow-Up Loop After Report Review

When the review gate returns `"Address changes"`, treat the user's feedback as a follow-up request about the research and recommendation.

1. Use the review gate's feedback as the user's comment: for tool-based review use `answers[1].custom_answer`; for plain-text fallback use the user's message content.
2. If the comment is empty, finish the workflow.
3. Classify the follow-up request:
   - **Clarification / elaboration** — explain a part of the report, expand on a recommendation, give an example, restate trade-offs, or answer a narrow question already covered by the current report.
   - **Small deepening request** — a narrow new question that the main agent can answer itself with limited additional investigation.
   - **Large deepening request** — a substantial new comparison, deeper evidence request, broader market scan, alternative evaluation, or follow-up that would materially benefit from fresh cross-model analysis.
4. Bias toward **running subagents again** for deepening requests. Main-agent-only answers should be limited to clarifications or clearly small follow-ups.

### If the request is clarification / elaboration or small deepening

1. Answer it yourself.
2. Update `{@artifacts_path}/brainstorm_report.md` by extending existing sections or creating new ones.
3. Keep the answer focused. Do not rewrite the whole report, just edit required parts.
4. After updating `{@artifacts_path}/brainstorm_report.md`, return to the **Review the Report** gate: re-read the report, then re-enter the same review flow. Prefer `ask_artifact_review` again, but keep supporting the same plain-text fallback until the user selects Proceed, Continue with comments, or Cancel.

### If the request is a large deepening request

1. Start a new follow-up round number at `1` and increment for each additional deep-dive pass.
2. Reuse the same `N` and model assignments from the initial run unless the user explicitly asked otherwise.
3. Spawn one fresh subagent per model using `spawn_subagent` **without changing the question across workers**.
4. Each follow-up subagent must read the current consolidated report before answering. Use `attachedFiles` with:
   - `{@artifacts_path}/brainstorm_report.md`
5. For each follow-up worker `i`, write to:
   - `{@artifacts_path}/brainstorm_followup_<round>_<index>.md`
6. Use a prompt like:
   > Read the current consolidated brainstorm report at `{@artifacts_path}/brainstorm_report.md`.
   >
   > Original question: <the user's original question>
   >
   > Follow-up question: <the user's review comment verbatim>
   >
   > Answer only this follow-up question. Do not rewrite the full report. Use sources for factual claims. Write a focused markdown note to `{@artifacts_path}/brainstorm_followup_<round>_<index>.md`.
7. Await each follow-up subagent, retry once if the output file is missing/empty, then read all valid follow-up notes.
8. Synthesize the changes to `{@artifacts_path}/brainstorm_report.md`.
9. Optionally write a temporary synthesis file to `{@artifacts_path}/brainstorm_followup_<round>_summary.md`, but the canonical artifact remains `brainstorm_report.md`.
10. After updating `{@artifacts_path}/brainstorm_report.md`, return to the **Review the Report** gate: re-read the report, then re-enter the same review flow. Prefer `ask_artifact_review` again, but keep supporting the same plain-text fallback until the user selects Proceed, Continue with comments, or Cancel.

### Loop behavior

- After every follow-up answer, return to the review gate (`ask_artifact_review` on `brainstorm_report.md`).
- Continue until the user selects Proceed, Continue with comments, or Cancel.
- Preserve prior follow-up rounds in the report; append new sections rather than replacing earlier ones.
- Keep the report readable. Prefer one concise follow-up section per review cycle.

---

## Present Final Result

When the gate returns `Proceed` or `Continue with comments`, whether through `ask_artifact_review` or the plain-text fallback:

1. Read the final `{@artifacts_path}/brainstorm_report.md` if needed.
2. Present a concise summary to the user (3-5 sentences) highlighting:
   - the current recommendation
   - whether any follow-up clarifications materially changed it
   - any open questions that remain
3. Point the user to `{@artifacts_path}/brainstorm_report.md` for the final artifact.
