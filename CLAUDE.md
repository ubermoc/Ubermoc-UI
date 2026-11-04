# UbermocUI work process

Every change is released as its own version. When the user says "push", "commit" or "release", do all of this without asking again:

1. Make the change in `UbermocUI/`.
2. Bump `## Version` in `UbermocUI/UbermocUI.toc` and add the entry at the top of `CHANGELOG.txt` (`UbermocUI N`, then `- Changed/Fixed: ...` lines).
3. Commit as `N: short summary` and push `main`.
4. Tag `vN` and push the tag.
5. Build the zip: `git archive --format=zip --prefix=UbermocUI/ -o UbermocUI-N.zip HEAD:UbermocUI` (write it outside the repo).
6. Create the GitHub release "Version N" with `gh release create vN UbermocUI-N.zip --title "Version N" --notes <changelog entry> --latest`.
7. Upload the same zip to CurseForge (project 1745809) with Claude in Chrome at `https://authors.curseforge.com/#/projects/1745809/files/create`: the Choose File button makes a hidden file input on click, so hook `HTMLInputElement.prototype.click`, click the button, then use file_upload on the new input. Keep the game versions copied from the previous file, type Release, paste the changelog entry, and click Add File.

"Pushed" is only true once the commit, tag, GitHub release and CurseForge upload are all done. Report each separately.

If the permission check blocks a public step such as `gh release create`, stop and tell the user which rule to allow instead of retrying.

## Where everything lives
- **GitHub:** repo `ubermoc/Ubermoc-UI`, branch `main`, remote `git@github.com:ubermoc/Ubermoc-UI.git` (SSH). The `gh` CLI is already logged in as `ubermoc` (scopes: repo, read:org, gist). Releases are named "Version N" on tag `vN`, marked Latest, with `UbermocUI-N.zip` attached. The Ubermoc Warcraft Mod Updater reads `/releases/latest` of this repo to install and update the addon, so the release MUST be a normal (non-prerelease) one with the zip attached, and the zip must keep the `UbermocUI/` top folder.
- **CurseForge:** project ID `1745809` (`X-Curse-Project-ID` in the TOC). Author upload page: https://authors.curseforge.com/#/projects/1745809/files/create. Public page: https://www.curseforge.com/wow/addons/ubermoc-ui. `CURSEFORGE-description.html` in this repo is the project description text; update it when features change.
- This repo has no packager workflow: GitHub and CurseForge are both done by hand from the steps above. I stay logged in to CurseForge in Chrome myself; never type my password. If Claude in Chrome is not available, stop and tell me.

## Related projects
This addon is one of four linked Ubermoc projects (the Updater installs it, Speech types for it, Forever is the controller-first addon for Forever and Midnight). How they fit together is in `~/.claude/CLAUDE.md`. Do not change Ubermoc Forever from here.
