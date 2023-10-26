set positional-arguments

default:
    zig build

@build target:
  zig build {{target}}

@test target:
  zig test {{target}}

@run:
  zig build run
