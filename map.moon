
-- some sort of a tile, and collision, map

require "collide"

import rectangle, setColor, getColor from love.graphics
import random from math
import insert from table

export *

style = {
  solid: 0
  solid_decor1: 16
  solid_decor2: 24

  top: 1
  bottom: 18

  back: 2
  back_floor: 13
  back_ceil: 14

  back_topleft: 17

  decor1: 4

  hot: {
    back: 3
    top: 6
    bottom: 5
  }

  door: {
    top: 19
    bottom: 27
  }

  inside: {
    back: 9
    top: 10
    decor1: 11
    decor2: 12
  }

}

hash_color = (r,g,b) ->
  r.."-"..g.."-"..b

nothing =  (tile) ->
  tile == nil or tile and tile.layer == 0

tile_types = {
  ["0-0-0"]: {
    sid: style.solid
    layer: 1
    auto: (x,y) =>
      above = @tiles[@to_i x, y - 1]
      if nothing above
        style.top
      else
        below = @tiles[@to_i x, y + 1]
        if nothing below
          style.bottom
        else
          r = random!
          if r > 0.98
            style.solid_decor1
          elseif r > 0.95
            style.solid_decor2
  }

  ["107-0-3"]: {
    sid: style.hot.back
    layer: 1
    auto: (x,y) =>
      below = @tiles[@to_i x, y + 1]
      if nothing below
        style.hot.bottom
      else
        above = @tiles[@to_i x, y - 1]
        if nothing above
          style.hot.top

  }

  ["198-132-49"]: {
    sid: style.back
    layer: 0
    auto: (x,y) =>
      below = @tiles[@to_i x, y + 1]
      if below and below.layer == 1
        style.back_floor
      else
        -- check if corner
        left = @tiles[@to_i x - 1, y]
        above = @tiles[@to_i x, y - 1]
        if left == nil and above == nil
          style.back_topleft
        elseif above and above.layer == 1
          style.back_ceil
        elseif random! > 0.95
          style.decor1
  }

  ["245-134-78"]: {
    sid: style.inside.back
    layer: 0
    auto: (x,y) =>
      above = @tiles[@to_i x, y - 1]
      if above == nil
        style.inside.top
      else
        r = random!
        if r > 0.98
          style.inside.decor1
        elseif r > 0.96
          style.inside.decor2
  }

  ["99-255-99"]: {
    layer: 0
    sid: style.door.top
    auto: (x,y) => insert @win_blocks, {x,y}
  }

  ["99-174-99"]: {
    layer: 0
    sid: style.door.bottom
    auto: (x,y) => insert @win_blocks, {x,y}
  }

  ["255-0-255"]: {
    layer: 0
    sid: style.back
    auto: (x,y, i) =>
      below = @tiles[@to_i x, y + 1]

      x, y = x * @cell_size, y * @cell_size
      box = Box x,y, 10, 10
      box.spawner = EnemySpawn Vec2d(x,y), random! * 2
      @spawners\add box

      if below
        below.sid
      else
        "nil"
  }


  ["255-0-0"]: { spawn: true }
}


class Tile extends Box
  new: (@sid, ...) => super ...
  draw: (sprite) => sprite\draw_cell @sid, @x, @y

class Map
  cell_size: 16

  self.from_image = (fname, tile_image, num_x=8) ->
    data = love.image.newImageData fname
    width, height = data\getWidth!, data\getHeight!

    spawn = {0,0}

    tiles = {}
    len = 1
    for y=0,height - 1
      for x=0,width - 1
        r,g,b,a = data\getPixel x, y
        if a == 255
          tile = tile_types[hash_color r,g,b,a]
          tiles[len] = if tile
            if tile.spawn
              print "found spawn"
              spawn = {x,y}
              nil
            else
              tile

        len += 1

    with Map width, height, tiles
      .sprite = Spriter tile_image, .cell_size, .cell_size, num_x
      .spawn = {spawn[1] * .cell_size, spawn[2] * .cell_size}


  new: (@width, @height, @tiles) =>
    @count = @width * @height
    layer = -> {}

    @min_layer, @max_layer = nil

    -- pixel size of the map
    @real_width = @width * @cell_size
    @real_height = @height * @cell_size

    @win_blocks = {}

    @spawners = UniformGrid @cell_size * 12

    -- do the autotiles
    for x,y,t,i in @each_xyt!
      if t and t.auto
        sid = t.auto self, x,y,t,i
        if sid == "nil"
          @tiles[i] = nil
        elseif sid
          @tiles[i] = { layer: t.layer, :sid }

    @layers = {}
    for x,y,t,i in @each_xyt!
      if t
        box = Tile t.sid,
          x * @cell_size, y * @cell_size,
          @cell_size, @cell_size

        @min_layer = math.min @min_layer or t.layer, t.layer
        @max_layer = math.max @max_layer or t.layer, t.layer

        @layers[t.layer] = layer! if not @layers[t.layer]
        @layers[t.layer][i] = box

    
    @win_blocks = for coord in *@win_blocks
      x,y = unpack coord
      Box x * @cell_size, y * @cell_size, @cell_size, @cell_size

    print "min:", @min_layer, "max:", @max_layer
    @solid = @layers[1]

  is_winning: (thing) =>
    for b in *@win_blocks
      return true if b\touches_box thing.box
    false
 
  to_xy: (i) =>
    i -= i
    x = i % @width
    y = math.floor(i / @width)
    x, y

  to_i: (x,y) =>
    return false if x < 0 or x >= @width
    return false if y < 0 or y >= @height
    y * @width + x + 1

  -- final x,y coord
  each_xyt: (tiles=@tiles)=>
    coroutine.wrap ->
      for i=1,@count
        t = tiles[i]
        i -= 1
        x = i % @width
        y = math.floor(i / @width)
        coroutine.yield x, y, t, i + 1

  -- get all tile id touching box
  tiles_for_box: (box) =>
    xy_to_i = (x,y) ->
      col = math.floor x / @cell_size
      row = math.floor y / @cell_size
      col + @width * row + 1 -- 1 indexed

    coroutine.wrap ->
      x1, y1, x2, y2 = box\unpack2!
      x, y = x1, y1

      max_x = x2
      rem_x = max_x % @cell_size
      max_x += @cell_size - rem_x if rem_x != 0

      max_y = y2
      rem_y = max_y % @cell_size
      max_y += @cell_size - rem_y if rem_y != 0

      while y <= max_y
        x = x1
        while x <= max_x
          coroutine.yield xy_to_i x, y
          x += @cell_size
        y += @cell_size

  draw: (viewport) =>
    for layer=@min_layer, @max_layer
      for tid in @tiles_for_box viewport.box
        tile = @layers[layer][tid]
        tile\draw @sprite if tile

  collides: (thing) =>
    for tid in @tiles_for_box thing.box
      return true if @solid[tid]

