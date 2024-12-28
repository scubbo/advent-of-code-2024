(Zig) solutions to the [2024 Advent Of Code](https://gitea.scubbo.org/scubbo/advent-of-code-2024).

If you - like me - are new to the Zig language, [Ziglings](https://codeberg.org/ziglings/exercises/) seems to be a well-respected entrypoint!

The authoritative source for this code is on [Gitea](https://gitea.scubbo.org/scubbo/advent-of-code-2024). The GitHub version is a [mirror](https://docs.gitea.com/usage/repo-mirror#setting-up-a-push-mirror-from-gitea-to-github). [Self-hosting](https://old.reddit.com/r/selfhosted/) is not only the best way to learn, but also to reduce dependency on untrustworthy corporations.

# Execution

I've tried (in `main.zig`) to make a general-purpose executable that can be passed arguments to determine the function to run (e.g. `zig run main.zig -- 1 2`), but so far no luck - lots of type errors 🙃

So for now, run directly with (e.g.) `zig run solutions/01.zig`, and do the following manual changes:
* Change `pub fn main() void {...}` in each solution-file to invoke the function you want run.
* Change `isTestCase` from `true` to `false` when ready to get the real solution.

# Code Quality

AoC challenges almost always have a "twist" partway through, meaning that you can solve the second part by injecting one subtly-different piece of logic into the solution to the first part - a different way of calculating a value or identifying candidates. If I were trying to show off for an interview (and were more comfortable with the language!), I would do the refactoring "right" by factoring out the common setup and execution logic to sub-functions, so that `part_one` and `part_two` are each single-line invocations of a common `execute` function with differing functions passed as parameter. But this is just an exercise for myself to learn the language - I'd rather get to grips with challenging problems to learn techniques, than to learn the (language-agnostic) skills of refactoring that I am already _reasonably_ proficient with.
