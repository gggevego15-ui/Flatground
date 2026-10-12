# FlatGROUND

Immersive first-person movement prototype built with Godot 4.6.1.

## Controls

- **WASD / Arrow keys** — move
- **Mouse** — look around
- **Shift** — sprint
- **Hold Ctrl** — crouch; moving quickly while crouched initiates a momentum slide
- **Hold Space** — jump / auto-bunny-hop
- **Esc** — release mouse; click the game to recapture it

## Run locally

Open this folder in Godot 4.6.1 or a newer stable Godot 4.x release and press **F5** to run the project.

## Automated Windows build

Push to `main` or `master`, or manually run **Godot Windows Build** under the repository's Actions tab. The workflow validates the project, exports a Windows executable and uploads `FlatGROUND-Windows` as an artifact.

## Prototype contents

The test arena is generated procedurally at startup and includes sprint lanes, cover, platforms, stairs, ramps, an industrial lighting pass, and a crosshair. Movement and camera parameters are exported on the player controller for iteration.
