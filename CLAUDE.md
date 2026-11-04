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
