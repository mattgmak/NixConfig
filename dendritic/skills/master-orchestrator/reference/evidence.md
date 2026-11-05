## 16. UI and sandbox evidence

A pull request that changes app UI carries visual proof. A pull request that changes Convex backend code or app logic carries sandbox proof. Never open the review without it.

Every app UI change carries evidence before the review opens. A small change takes no exception: a badge, a chip, or a copy line still needs one artifact per changed screen.

Capture it from the real app on a leased simulator, built on the mini. Publish it on the pull request as a release asset shown inline. A pull request without that block waits at the gate, and the body names the missing artifact.

| Change | Evidence |
|---|---|
| static element, layout, or copy | one screenshot per changed state |
| dynamic or behaviour change | one clip of 20 seconds or less |
| Convex schema, query, mutation, or action | one sandbox run that exercises the change, with its result |
| app logic without a visible surface | one sandbox run that shows the new value or path |
| both UI and logic | every artifact above |

An evidence run reuses the dev client already on the simulator when its native fingerprint matches the tree. Build only on a mismatch. The method sits in `reference/macos-remote-build.md`.

Steps for UI:

1. Ask the user before the first simulator command. The repo forbids an automatic run.
2. Start the sandbox and read the origin rule in `docs/agents/sandbox.md`.
3. Lease a simulator from the manzanas fleet. Install the dev client. Launch the app.
4. Drive the screens with `argent` on the leased device. Record the trigger twice: before and after.
5. Keep a working copy under `/tmp/agent-tmp/<project>/evidence/<ticket>/` while you capture.
6. Publish every artifact on the pull request. Never commit an evidence file into the repository unless the ticket asks for a tracked file. Upload it as a pull request attachment or a release asset, and link it from the body.
7. Publish motion as an animated GIF. A body gives no player. The renderer strips a `<video>` tag, and an mp4 inside an image tag shows a broken image. A GIF plays inline and loops.
8. Add an `## Evidence` block to the body. Name the artifact, the screen, and the proof it gives. The block holds no local path and no untracked file name.

Steps for backend and app logic:

1. Start the sandbox on the lane branch: `pnpm sandbox:up`. Read the status output before you trust it.
2. Seed a participant through the sandbox tools. Use the onboarding fixture, not a hand-made row.
3. Run the changed path. Call the query, send the mutation, or open the screen that reads it.
4. Capture the request, the response, and the stored document. Save the log or the screenshot under `/tmp/agent-tmp/<project>/evidence/<ticket>/`.
5. Add a `## Verification` block to the body. State the command or tap path, the observed result, the sandbox id, and one exit code per gate.
6. Stop the sandbox and say so in the report.

Rules:

- The proof shows the real app on a real simulator, against the real sandbox. A mock or a web build is a defect.
- Replace every network identifier with a placeholder such as `sandbox-host` or `simulator-1`.
- A clip keeps the dish, the value, or the state on screen long enough to read.
- A pull request without proof waits at the gate. Name the missing artifact.
- A green unit test does not replace the sandbox run. Say which claim the run settles.
- Release the lease and stop the sandbox after the capture.
- A reviewer reads the proof in the pull request, with no clone. An uploaded image renders inline, and a release asset opens on one click. A clip too large to upload gets a link beside its key frames.
- Each changed screen gets its own artifact. One screenshot of a screen that did not change proves nothing.
- An evidence file stays out of the repository. Commit one only when a ticket names it as a tracked artifact.
- Keep each uploaded image small. Shrink a clip with `ffmpeg` before the upload, and keep the value or the dish name readable.
- A GIF stays under 10 MB at about 420 pixels wide. Confirm the frame count, and confirm one frame shows the action. A frame the eye cannot read is no proof.
- A person can reach one route that code cannot: the web editor turns a dropped clip into an inline player. Probe `POST https://api.github.com/user-attachments/assets` and expect 404. No `gh api` call creates an attachment, and a release asset gives no player. Ask the user when a true player is needed.
- The GIF is the default. It needs no session, no account, and no click. Offer the player route once, then ship the GIF.
- When the app must run, build it on the mini and read `reference/macos-remote-build.md` first.
