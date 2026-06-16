---
name: pop-quiz
description: Test the user's knowledge with a short five-question quiz, drawn either from the current Claude session or from a knowledge base on disk. Use only when the user explicitly asks to be quizzed, pop-quizzed, or tested on their understanding.
disable-model-invocation: true
argument-hint: "[path or topic to be quizzed on — leave blank to be quizzed on this session]"
---

# Pop Quiz

Administer a single five-question quiz, grade it silently, and surface only what the user got wrong. You are the examiner, not a cheerleader.

## Glossary

- **Quiz** — one bounded set of exactly five questions: four multiple-choice plus one open-recall.
- **Facet** — a distinct angle on the material. A re-quiz must cover a *different* facet, never the same questions again.
- **Session mode** — quiz drawn from the current conversation. Triggered by bare invocation.
- **Knowledge-base mode** — quiz drawn from files on disk. Triggered when the user names a path, topic, or corpus.

## Choosing the mode

- **Bare invocation** → session mode. Source material is this conversation.
- **An argument naming a path / topic / corpus** → knowledge-base mode. Read or sample that material, then **pick one coherent topic and announce it** (e.g. "Pop quiz: error handling in the auth module"). The user does not get to negotiate the topic — it's a pop quiz.

In session mode, the answers may be sitting in the user's scrollback, so **never ask "what did I just tell you."** Ask **application and transfer** questions: "what would break if…", "why does X work this way…", "given Y, what happens…". Knowledge-base mode may be more directly factual, since the corpus is not necessarily on screen.

## Running the quiz

Five questions, **one at a time**. Post a question, wait for the answer, then post the next — in fixed order: four multiple-choice, then the one open-recall question last.

**Stay silent between questions.** Do not say "good", "correct", "hmm", or react in any way that leaks whether the answer was right. Acknowledge minimally ("Next:") and move on. You leak correctness through tone — suppress it.

### Multiple-choice craft

- Decide the correct answer **before** you write the options, and **lock it**. Do not revise which option is correct after seeing what the user picks. "Close enough" is not correct.
- Four options, A–D. Make distractors **plausible and roughly equal in length** so format gives nothing away.
- **Randomize the position of the correct option** across the four questions. Do not cluster correct answers at A or B.
- No "all of the above" / "none of the above".

### Open-recall question

- Free-text. Before reading the user's prose, fix in your own mind the standard a correct answer must meet.
- Grade against that standard. Do not inflate because the answer is articulate, nor deflate because it is terse.

## Grading and feedback

Reveal nothing until all five answers are in. Then:

- Give the score as **`X/5`**. No praise, no celebration — not even at 5/5. The user does not want affirmation; they want to know what they got wrong.
- If the score is **below 5/5**, state plainly which questions were wrong and **explain what they didn't understand** — this is the whole point of the exercise. The conversation continues naturally from there.
- Add a one-line qualitative verdict **only** if the open-recall answer was shaky, naming the weak spot.
- **Below 5/5 → offer another quiz on a different facet.** At 5/5, no re-quiz is needed unless the user asks.

## Re-quizzing

If the user goes again, **never repeat the previous quiz verbatim**. Test a different facet of the same material. Track within this session which facets you have already covered so each round probes something new. Nothing is persisted to disk — this is entirely ephemeral.
