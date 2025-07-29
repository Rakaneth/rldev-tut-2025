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

![Moving Character](assets/screenshots/Week1.gif)

This week, I decided to lay a good bit of plumbing down - more than one would expect for the simple task of getting an @ moving. I have the benefit of some experience here, as I was recently tinkering with Odin and Raylib before this. I'll be using an old version of the Micro Roguelike Tileset from [Kenney](https://kenney.nl/assets/micro-roguelike), embedding it directly into the executable. Since many asset licenses prohibit redistributing assets, I like that it is relatively painless to embed a file into an executable with Odin's `#load` function.

I am using the built-in Raylib 2D camera for zoom. I haven't decided if I will use scrolling in this game or not, but if I do, I will wind up implementing my own hand-rolled basic camera that I've been using in toy roguelikes for many years. That decision can wait until next week. The play area will be 40 by 30 tiles, with UI elements going directly on top.

Another goal I had was to add just a bit more polish than I normally would with ASCII tiles. I have the bones of smooth movement in this current implementation, but time will tell if I continue down this path.

### 2025-07-16

Added the Windows build script and moved the week1 tag. I am satisified for Week 1.

## Week 2 (2025-07-22) Basic entities, map, dungeon generation

No new code added today; currently brainstorming how I will lay out maps. My goto method is a 1-dimensional array indexed by width.
I will try to set up a new branch, as well as tags, for each week.

### 2D index into 1D array

Imagine a 3x3 map:

```
###
#X#
###
```

The `X` is at point (1, 1) in a standard coordinate system with y increasing downwards. Now, moving left to right, then top to bottom, count from zero through the map:

```
012
345
678
```

Each number is an index into the array storing the map. Thus, our point (1, 1) is at index 4, There is a simple way to calculate this index for any point int he map, given the width of the map (here 3):

```
index = y * map_width + x 
    -> 1 * 3 + 1 
    -> 4
```

In fact, there is also a way to decompose an array index into a unique coordinate, again given the width of the map:

```
x = index % map_width
y = floor(index / map_width) /* Integer Division */
```

As in the above example:
```
x = 4 % 3 -> 1
y = 4 / 3 -> 1
```

I usually wrap these operations into two helper functions that I call `idx` and `deidx` respectively. Algorithms and procedures will work with 2D coordinates and go into 1D mode only when interfacing with the raw data.

I've tinkered a lot with this design - not just in Odin, but in other languages like C - and I do like this pattern for low-level languages.

### Tiles

Tiles themselves will be an enumeration. Odin does magical things with enumerations (see my sprite atlas implementation).
That enum will look something like this:

```odin
Tile :: enum {
    NullTile,
    Wall,
    Floor,
    DoorClosed,
    DoorOpen,
    StairsDown,
}
```

The map data will be an array whose items are members of this enumeration. This allows the map data to be lightweight.
Anything else associated with tiles - like sprites and terrain properties - can be dealt with using switch statements at the sites where they are needed.

### 2025-07-23

I am going to stick with what I know for the map, using the system I detailed above. I will also use Odin's parametric polymorphism (generics) features to make the grid structure generic, so I have the option to use it for other things like LOS and explored tiles.

I have begun refactoring things to separate files as well. 

Basic map drawing is in. Still haven't decided if I want to support scrolling maps yet.

## Week 3 (2025-07-29) Field of View, basic enemies

I'm still stuck on Week 2 because of tileset issues. I've been experimenting with map generation methods and with all of them, I'm feeling like the tileset is missing a couple of crucial tiles. I also don't like how the vertical walls have so much space, which looks strange when I have the player stop at walls.

I am strongly considering changing tilesets and have been looking at others. I might be able to make this tileset work with some extra code to possibly flip tiles. I either need a single-block solid wall tile or three more tiles: 4-way intersection (&#x253C;), and two T-insersections (&#x2534; &#x252C;)