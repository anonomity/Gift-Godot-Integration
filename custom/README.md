Add "custom" modules that you don't want to submit to the public "common" repository here.

Projects are identified by a `.godot-twitch-games-project` file in the root of the custom module (e.g. `custom/example/.godot-twitch-games-project`).

Custom games are loaded from the `games` folder in the same organizational structure as `scene/games` (e.g. `custom/example/games/example-game`).

Custom modules **can** be git repositories! There is an ignore on this directory because we don't want to treat them as git submodules.