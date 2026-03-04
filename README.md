# Ralph Wiggum Loop starter

A Ralph Wiggum Loop is an unsupervised agentic coding loop you can run with any frontier model. It was originally designed with Claude Code CLI in mind, and that's what this starter kit uses. (Though you can adapt this model for other agentic coding CLIs, see footnote.)

## A Ralph Wiggum Loop is just a bash script on repeat

Neither a framework nor an agent, a Ralph Wiggum Loop is a bash script and prompt template that uses a specific way of structuring engineering projects so an agent can execute autonomously, one task at a time, with a fresh context window each iteration.

The best way to think about a Ralph Wiggum Loop is its like _[50 First Dates](https://www.youtube.com/watch?v=Q_2AbjYeSMI)_ if Drew Barrymore had been a software engineer. Every time the loop runs, the engineer wakes up with no memory. It only has a prompt and two markdown files to tell it what to do today. When it finishes its task, it goes to bed, only to wake up with amnesia anew the next morning (loop). (Maybe it should be called "50 First Loops?")

So for each iteration, Claude Code: 

1. Reads a **spec.md** and **implementation-plan.md** files
3. Picks the highest-priority unchecked task
4. Implements the task
5. Marks it done in **implementation-plan.md** 
6. **exits**

Watch [this explainer](https://www.youtube.com/watch?v=I7azCAgoUHc) for the best breakdown of how it works and how it helps "keep your agent smart" by clearning out the context window on every iteration.

### Five Downsides to Know

1. **Not token-efficient.** Each iteration re-reads the spec from scratch. Parallel loops multiply usage exponentially.
2. **Quality vs. attention tradeoff.** You're trading some code quality for reduced oversight.
3. **Big specs cause context rot.** Keep spec + plan as brief as possible. If a task needs too much context, break it down.
4. **One bad test poisons future loops.** Red/green TDD mitigates this, but doesn't eliminate it.
5. **Speccing is hard.** If you don't know exactly what you want, try exploration mode first — spend 5 minutes brain-dumping, let Claude write a rough plan, run Ralph overnight, and use the output to inform a proper spec.

## How this implementation is special

This starter combines Test Driven Development (TDD) with Claude Code in headless mode (using the `-p` flag). On each iteration, Claude Code:

1. Reads a **spec.md** and **implementation-plan.md** files
3. Picks the highest-priority unchecked task
4. Writes a **failing test** first (red)
5. Implements until it **passes** (green)
5. Runs the test suite 
6. Corrects any issues
7. Marks the task done in **implementation-plan.md** 
8. **exits**
9. Changes are git-committed by the script, not the agent, to make it easier to see what the agent implemented and rollback things, without giving the agent too much control

On the next iteration, Claude Code starts with a **fresh context window**, no memory of the previous loop, and reads the spec again. Instead cramming everything into one long session where performance degrades (the "dumb zone" after ~100k tokens), each iteration gets a clean slate with lots of memory for solving one problem at a time. The spec and implementation plan are the source of truth, not previous context.

### Tasks Fail Gracefully

When Claude can't complete a task:

1. **First attempt fails** → rolls back with `git checkout`, adds a `⚠️` note explaining what went wrong
2. **Second and third attempts** → same: rollback and another note
3. **After 3 failures** → Claude skips the task and moves on
4. **Cleanup task** (second-to-last) → retries stuck tasks one more time, writes `STUCK.md` if they still fail
5. **README task** (last) → documents the project as-built, noting incomplete features

The script also stops if **all** remaining tasks have 3+ failures, since looping further would waste tokens.

### Configuration

All configuration is via environment variables:

| Variable | Default | Description |
|---|---|---|
| `ON_LIMIT` | `overnight` | Rate limit behaviour: `overnight`, `wait`, or `stop` |
| `WAKE_HOUR` | `10` | Hour (24h format) after which overnight mode stops |
| `ALLOWED_TOOLS` | *(Node.js defaults)* | Tools Claude is allowed to use (see below) |

## Tutorial

### Step 0: Prerequisites

- **macOS or Linux**
- **Node.js 22+** — `brew install node`
- **Claude Code** — `npm install -g @anthropic-ai/claude-code`
- **A Claude plan** — Max ($100-200/month) for daily use, Pro ($20/month) for overnight exploration runs

Clone this repo into your project (or just copy `ralph.sh` and `prompt.md`):

  ```bash
  git clone https://github.com/nearestnabors/ralph-wiggum-loop-starter.git
  cd ralph-wiggum-loop-starter
  ```

Planning is everything. If you try to skimp out on this step, you're going to get slop. Erors cascade across every iteration. 

So get a hot cup of caffeine and put on some lofi focus beats. You're going to be talking to Claude for awhile!

### Step 1: Bidirectional prompting

In the same folder as `prompt.md` and `ralph.sh`, open Claude Code in your terminal of choice: 

```bash
claude
```

Have a conversation where **you and Claude ask each other questions** until you're both aligned:

```bash
I want to build [describe your project]. Before we start, I need you to:
1. Ask me clarifying questions about anything that's ambiguous
2. Tell me what assumptions you're making so I can confirm or correct them
3. Once we're aligned, write a spec.md outlining the tech stack and specifics and implementation-plan.md, listing the tasks to be done. Be thorough and as descriptive as possible, like you're giving instructions to a team of junior engineers who can be trusted to execute but not to strategize. Make note of anything we're NOT doing, specifically. Externalize internal assumptions!

Remember to end any task list with:
- [ ] Revisit any stuck/unfinished tasks above. If still stuck, write STUCK.md describing what was tried and why it failed, then mark this task as done so you can move on
- [ ] Write/update README.md with setup instructions, dependencies, configuration, and how to run the project
```

Go through multiple rounds. Get another cup of caffeine. Don't rush this. I like to follow up in a fresh Claude Code conversation with:

```bash
Review spec.md and implmentation-plan.md with a critical eye. Do they still need work? Are they missing anything? List your concerns and confidence level.
```

This will leave you with two new files: 

| File | What it does |
|---|---|
| `spec.md` | Describes your project: architecture, tech stack, conventions, directory structure. Claude reads this at the start of every iteration. |
| `implementation-plan.md` | A checklist of tasks using `- [ ]` markdown checkboxes. Claude picks one per iteration, does it, and checks it off. |

### Step 2: Claude writes the spec and plan

After the conversation, Claude produces `spec.md` and `implementation-plan.md`. The implementation plan should be a checklist:

```markdown
# Implementation Plan

- [ ] Set up project structure and dependencies
- [ ] Create database schema for users table
- [ ] ...
- [ ] Revisit any stuck/unfinished tasks above. If still stuck, write STUCK.md describing what was tried and why it failed, then mark this task as done
- [ ] Write/update README.md with setup instructions, dependencies, configuration, and how to run the project
```

The last two tasks are important: 

* the **cleanup task** retries anything that got stuck and writes a report
* the **README task** documents whatever actually got built

### Step 3: Review every single line

Read both documents completely. If you don't understand or disagree with something, edit it and/or talk it out with Claude now. Once Ralph starts running, each iteration builds on the previous one, compounding assumptions and bad ideas.

### Step 4: Customise prompt.md

Edit the "Project Context" section in `prompt.md` to match your project's language, test framework, and conventions. See `example/prompt.md` for a template.

You can also prompt Claude:

```bash
Update the Project Context section of prompt.md to match what we agreed to in spec.md.
```

### Step 5: Install the right tools

Visit [skills.sh](https://skills.sh) and make sure you install the skills necessary to perform according to `spec.md`. 

Reference any available MCP tools in prompt.md so the agent knows they're there.

### Step 6. Initialise git (Ralph auto-commits each completed task)

```bash
git init && git add -A && git commit -m "initial plan"
```

### Step 7. Run the loop

```bash
chmod +x ralph.sh
./ralph.sh
```

### Step 8. Babysit the first few loops

Watch the first 2–3 iterations. You're looking for:

- Is it picking tasks in a sensible order?
- Is it following the spec's conventions?
- Are the tests meaningful (not just `expect(true).toBe(true)`)?
- Is it staying focused on one task per iteration?

**If it goes off track:** `Ctrl+C`, edit `spec.md` or `implementation-plan.md`, and restart.

### File Reference

| File | Purpose |
|---|---|
| `ralph.sh` | The loop script |
| `spec.md` | Architecture, conventions, constraints (you write this) |
| `implementation-plan.md` | Task checklist (you write this) |
| `prompt.md` | Instructions for Claude each iteration (customise from example) |
| `ralph-logs/` | Timestamped logs from each iteration (auto-created) |
| `DONE` | Created by Claude when all tasks are complete |
| `STUCK.md` | Report on tasks that couldn't be completed |

## Pro tips

### Options for dealing with rate limits

Claude's usage limits reset on a **rolling 5-hour window** from your last session, not at a fixed time. The script detects rate limits and responds based on the `ON_LIMIT` setting:

| Mode | Behaviour |
|---|---|
| `overnight` (default) | Sleeps until reset if it's before your `WAKE_HOUR`. Stops if the reset would be after, so your morning tokens are preserved. |
| `wait` | Always sleeps until reset, no matter what time. |
| `stop` | Exits immediately. |

Update these variables in `ralph.sh` to reflect your usage:

```bash
WAKE_HOUR=8        # stop if reset is after 8am
ON_LIMIT=wait      # always sleep until reset
```

### Running in the background

```bash
# tmux keeps it running if your terminal disconnects
brew install tmux
tmux new -s ralph
./ralph.sh
# Detach: Ctrl+B, then D
# Reattach: tmux attach -t ralph
```

### Morning inspection

```bash
git log --oneline              # see what Ralph did
npm test                       # run the tests yourself
git show <hash>                # review a specific iteration
git revert <hash>              # undo a bad iteration
git bisect start               # find which iteration broke something
```

If `STUCK.md` exists, read it to learn what couldn't be completed and why.

### Running with different agentic coding CLI tools

There's nothing Claude-specific about this pattern. The core loop is just a bash script calling a CLI tool with `-p`  But this example is tightly coupled to Claude Code because of the `claude -p` command and `--allowedTools` flag syntax.
Other agentic coding CLIs that support a similar headless mode:

* **[Codex CLI](https://developers.openai.com/codex/cli/) (OpenAI)** `codex exec "prompt"` with `--sandbox` flags
* **[Gemini CLI](https://geminicli.com/) (Google)** has a non-interactive mode
* **[aider](https://aider.chat/)** `aider --message "prompt"` for one-shot runs
* **[Cursor CLI](https://cursor.com/cli)** more IDE-oriented but has some headless capability

The loop would work with any of these in principle if you swap the `claude -p` line for the equivalent command. But each has different flag syntax for tool permissions, different rate limit messages, and different model selection, etc. Fork this repo and share it with them with this prompt:

```bash
Rewrite `ralph.sh` and `example/*` to work with this CLI.
```

### Model Switching

Each `claude -p` invocation can target a different model with `--model`. This is optional, and Sonnet is a solid default.

| Model | Flag | Best for |
|---|---|---|
| Haiku 4.5 | `--model claude-haiku-4-5-20251001` | Fast implementation, simple tasks |
| Sonnet 4.5 | `--model claude-sonnet-4-5-20250929` | General-purpose workhorse |
| Opus 4.6 | `--model claude-opus-4-6` | Complex reasoning, review, architecture |

Claude Code also has a built-in **`opusplan`** mode (`--model opusplan`) that uses Opus for planning and Sonnet for execution, a good middle ground.

To use a specific model, either edit the `claude -p` line in `ralph.sh` or set `ANTHROPIC_MODEL` in your environment:

```bash
ANTHROPIC_MODEL=claude-haiku-4-5-20251001
```

## Contribute your findings!

If you make a version that works well for your CLI or add some features that make it work even better, feel free to submit a PR!

## Credits

* Thanks to Roman for [his epic explanation that started me on this journey](https://www.youtube.com/watch?v=I7azCAgoUHc). 
* Thanks to Simon Willison for the red/green TDD and "first run the tests" patterns from [his Agentic Engineering Patterns](https://simonwillison.net/guides/agentic-engineering-patterns/). (Mandatory reading if you get into this way of coding.)
* And thanks to [Geoffrey Huntley for creating the idea of a Ralph loop in the first place](https://ghuntley.com/ralph/)

## License

MIT license!
