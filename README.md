# RoguelikeDev Does the Complete Roguelike Tutorial 2025

![RogueLike Dev Logo](assets/screenshots/GEyBFMC.png)

Greetings! This is my entry in [/r/roguelikedev's](https://www.reddit.com/r/roguelikedev/comments/1luh8og/roguelikedev_does_the_complete_roguelike_tutorial/) Complete Roguelike Tutorial 2025 event. My goals are as such:

* Produce a playable, reasonably complete game
* Make use of [Odin](https://odin-lang.org), a general-purpose programming language that picks up where C left off, and in the process, learn more about the language
* Make use of [Raylib](https://raylib.com), a code-first programming library with bindings to many languages (including Odin), instead of a terminal-emulation library (like my favorite [BearLibTerminal](https://github.com/cfyzium/BearLibTerminal))

# DevLog

## Week 1 (2025-07-15) - Development environment, moving @

### Dev Environment

VS Code with the following required extensions:

* [C/C++](https://marketplace.visualstudio.com/items?itemName=ms-vscode.cpptools)
* [Odin Language](https://marketplace.visualstudio.com/items?itemName=DanielGavin.ols)

I am working in a WSL Ubuntu instance on a Windows host. Windows build scripts will come soon.

### Plumbing Work

![Moving Character](assets/screenshots/Week1.png)

This week, I decided to lay a good bit of plumbing down - more than one would expect for the simple task of getting an @ moving. I have the benefit of some experience here, as I was recently tinkering with Odin and Raylib before this. I'll be using an old version of the Micro Roguelike Tileset from [Kenney](https://kenney.nl/assets/micro-roguelike), embedding it directly into the executable. Since many asset licenses prohibit redistributing assets, I like that it is relatively painless to embed a file into an executable with Odin's `#load` function.

I am using the built-in Raylib 2D camera for zoom. I haven't decided if I will use scrolling in this game or not, but if I do, I will wind up implementing my own hand-rolled basic camera that I've been using in toy roguelikes for many years. That decision can wait until next week. The play area will be 40 by 30 tiles, with UI elements going directly on top.

Another goal I had was to add just a bit more polish than I normally would with ASCII tiles. I have the bones of smooth movement in this current implementation, but time will tell if I continue down this path.
