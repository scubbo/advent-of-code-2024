(Zig) solutions to the [2024 Advent Of Code](https://gitea.scubbo.org/scubbo/advent-of-code-2024).

If you - like me - are new to the Zig language, [Ziglings](https://codeberg.org/ziglings/exercises/) seems to be a well-respected entrypoint!

The authoritative source for this code is on [Gitea](https://gitea.scubbo.org/scubbo/advent-of-code-2024). The GitHub version is a [mirror](https://docs.gitea.com/usage/repo-mirror#setting-up-a-push-mirror-from-gitea-to-github). [Self-hosting](https://old.reddit.com/r/selfhosted/) is not only the best way to learn, but also to reduce dependency on untrustworthy corporations.

# Execution

I've tried (in `main.zig`) to make a general-purpose executable that can be passed arguments to determine the function to run (e.g. `zig run main.zig -- 1 2`), but so far no luck - lots of type errors 🙃

So for now, run directly with (e.g.) `zig run solutions/01.zig`, and do the following manual changes:
* Change `pub fn main() void {...}` in each solution-file to invoke the function you want run.
* Change `isTestCase` from `true` to `false` when ready to get the real solution.