require 'gosu'
# Gosu is a lightweight 2D game development library for the Ruby programming language (and also usable in C++). It provides an easy way to:

# Open a game window and set up a main loop (update/draw).
# Draw shapes, images, and text on the screen.
# Play sounds and music.
# Handle input from the keyboard, mouse, or game controllers.


# -----------------------------------------------------------------------------
# Helper Methods
# -----------------------------------------------------------------------------
#
# These methods help us draw shapes in Gosu. They are defined as plain Ruby
# methods (not inside a class) because they do not need to store any state.
#

# Draw a filled rectangle on screen.
def draw_rect(x, y, width, height, color, z)
  Gosu.draw_quad(
    x,            y,            color,
    x + width,    y,            color,
    x + width,    y + height,   color,
    x,            y + height,   color,
    z
  )
end

# Draw a filled circle by drawing "triangles" around its center.
# segments is how many triangle "slices" we use to approximate a circle.
def draw_circle(cx, cy, radius, segments, color, z)
  angle_step = 2 * Math::PI / segments
  points = []

  # Collect points around a circle.
  segments.times do |i|
    angle = i * angle_step
    x = cx + Math.cos(angle) * radius
    y = cy + Math.sin(angle) * radius
    points << [x, y]
  end

  # Draw triangle slices from the center of the circle.
  segments.times do |i|
    x1, y1 = points[i]
    x2, y2 = points[(i + 1) % segments]  # Wrap around to the first point
    Gosu.draw_triangle(
      cx,  cy,  color,
      x1,  y1,  color,
      x2,  y2,  color,
      z
    )
  end
end

# -----------------------------------------------------------------------------
# FlappyBird Window (Main Game Class)
# -----------------------------------------------------------------------------
#
# This class represents our main game window. It inherits from Gosu::Window,
# which provides the game loop (update/draw) and keyboard/mouse input hooks.
#
class FlappyBird < Gosu::Window
  # Constants (UPPER_CASE) for configuration.
  WIDTH        = 640   # Window width
  HEIGHT       = 480   # Window height
  GRAVITY      = 0.4   # How quickly the bird falls
  JUMP_POWER   = -8    # Upward velocity when flapping
  PIPE_WIDTH   = 60    # Width of each pipe
  PIPE_GAP     = 200   # Gap between top and bottom pipes
  SCROLL_SPEED = 3     # How quickly pipes move from right to left

  def initialize
    # Call Gosu::Window's initialize, passing our width & height.
    super WIDTH, HEIGHT
    self.caption = "Flappy Ruby (Simplified)"

    # Create a bird instance.
    @bird = Bird.new(self)

    # Store an array of pipe objects.
    @pipes = []

    # Keep track of the score.
    @score = 0

    # Simple game state flags.
    @game_over = false
    @started   = false  # Game doesn't start until the player presses Space.

    # Create a Gosu font for drawing text on the screen.
    @font = Gosu::Font.new(32)

    # Generate the initial pair of pipes.
    generate_pipe
  end

  # update is called ~60 times per second. This is where game logic happens.
  def update
    # If the player hasn't pressed space yet, do nothing.
    return unless @started

    # If the game is over, stop updating the game logic.
    return if @game_over

    # Update the bird's position (gravity, etc.).
    @bird.update

    # Move the pipes leftward.
    update_pipes

    # Check if the bird hit a pipe or went out of bounds.
    check_collisions

    # Update the score for every pipe the bird passes.
    update_score
  end

  # draw is called ~60 times per second. This is where you render graphics.
  def draw
    # Draw background. For simplicity, just draw a gradient from light-blue to green.
    draw_background

    # Draw the bird (a yellow circle).
    @bird.draw

    # Draw each pipe (top and bottom). We'll just draw rectangles.
    @pipes.each(&:draw)

    # Draw the score in the top-left corner.
    @font.draw_text("Score: #{@score}", 10, 10, 2, 1.0, 1.0, Gosu::Color::BLACK)

    # If game hasn't started, show "Press Space to Start".
    unless @started
      message = "Press Space to Start"
      center_x = (WIDTH - @font.text_width(message)) / 2
      center_y = HEIGHT / 2
      @font.draw_text(message, center_x, center_y, 2, 1.0, 1.0, Gosu::Color::WHITE)
    end

    # If game is over, show "Game Over! Press Space to Restart".
    if @game_over
      message = "Game Over! Press Space to Restart"
      center_x = (WIDTH - @font.text_width(message)) / 2
      center_y = HEIGHT / 2
      @font.draw_text(message, center_x, center_y, 2, 1.0, 1.0, Gosu::Color::RED)
    end
  end

  # button_down is called whenever a key is pressed (or mouse, if you configure it).
  def button_down(id)
    if (id == Gosu::KB_SPACE) || (id == Gosu::MS_LEFT)
      # If game not started, start it.
      if !@started
        @started = true
      # If game is over, reset everything and start again.
      elsif @game_over
        reset_game
        @started = true
      # Otherwise, make the bird flap (jump).
      else
        @bird.flap
      end
    end

    # If user presses Esc, close the game window.
    close if id == Gosu::KB_ESCAPE

    # Always call super to preserve default behavior.
    super
  end

  private

  # Helper: Draw a simple gradient background from top (sky blue) to bottom (green).
  def draw_background
    top_color    = Gosu::Color.new(0xFF87CEEB)  # Sky blue
    bottom_color = Gosu::Color.new(0xFF228B22)  # Forest green
    Gosu.draw_quad(
      0,     0,         top_color,
      WIDTH, 0,         top_color,
      WIDTH, HEIGHT,    bottom_color,
      0,     HEIGHT,    bottom_color,
      0
    )
  end

  # Creates one pair of pipes (top and bottom). Each pipe is a Pipe object.
  def generate_pipe
    # Choose a random opening in the vertical space for the bird to pass.
    # The top pipe goes from the top until 'opening_y',
    # and the bottom pipe goes from 'opening_y + PIPE_GAP' to the bottom.
    opening_y = rand(50..(HEIGHT - 50 - PIPE_GAP))

    # Create the top pipe, which starts at (WIDTH, 0).
    # Its height extends down to 'opening_y'.
    top_pipe = Pipe.new(self, WIDTH, 0, opening_y)

    # Create the bottom pipe, which starts at (WIDTH, opening_y + PIPE_GAP).
    # Its height is from that point to the bottom of the screen.
    bottom_pipe = Pipe.new(
      self,
      WIDTH,
      opening_y + PIPE_GAP,
      HEIGHT - (opening_y + PIPE_GAP)
    )

    @pipes << top_pipe
    @pipes << bottom_pipe
  end

  # Move each pipe to the left and remove pipes that go off-screen.
  # If our last pipe has moved far enough, generate a new pipe pair.
  def update_pipes
    @pipes.each { |pipe| pipe.update(SCROLL_SPEED) }

    # Remove any pipes that have completely left the left side of the screen.
    @pipes.reject! { |pipe| pipe.x + pipe.width < 0 }

    # If the last pipe is halfway across the screen, generate a new pipe.
    # This keeps them spaced out so the bird always has a new challenge.
    if @pipes.last && @pipes.last.x < WIDTH - 200
      generate_pipe
    end
  end

  # Check if the bird hits the top/bottom of the window or collides with any pipe.
  def check_collisions
    # If bird goes above top or below bottom (minus bird’s size), game over.
    if @bird.y < 0 || @bird.y > (HEIGHT - @bird.radius)
      @game_over = true
      return
    end

    # Check collision with pipes.
    @pipes.each do |pipe|
      # Horizontal collision: if the bird is within the pipe's x-range.
      if @bird.x + @bird.radius > pipe.x && @bird.x - @bird.radius < pipe.x + pipe.width
        # Vertical collision: depends on whether it's a top pipe or bottom pipe.
        # Top pipe: pipe.y = 0, pipe.height = opening_y
        # Bottom pipe: pipe.y = opening_y + PIPE_GAP
        if pipe.y == 0
          # Top pipe: if bird's top edge is above the bottom of the top pipe.
          if @bird.y - @bird.radius < pipe.height
            @game_over = true
            return
          end
        else
          # Bottom pipe: if bird's bottom edge is below the top of the bottom pipe.
          if (@bird.y + @bird.radius) > pipe.y
            @game_over = true
            return
          end
        end
      end
    end
  end

  # Increase the score by 1 whenever the bird passes a 'top pipe' that hasn't been scored yet.
  def update_score
    # For each top pipe, if the bird has flown past it (bird.x > pipe.x + pipe.width),
    # and we haven't scored it yet, increase score and mark it scored.
    @pipes.each do |pipe|
      next unless pipe.y == 0        # Only the top pipe (y=0).
      next if pipe.scored            # Skip if already scored.

      if @bird.x > (pipe.x + pipe.width)
        @score += 1
        pipe.scored = true
      end
    end
  end

  # Resets the game to its initial state so we can play again.
  def reset_game
    @bird     = Bird.new(self)
    @pipes    = []
    @score    = 0
    @game_over = false
    @started   = false
    generate_pipe
  end
end

# -----------------------------------------------------------------------------
# Bird Class
# -----------------------------------------------------------------------------
#
# The Bird has an x, y position and a velocity.
# It updates its position based on gravity, and can flap (jump).
#
class Bird
  attr_reader :x, :y, :radius

  def initialize(window)
    @window   = window
    @x        = 50
    @y        = FlappyBird::HEIGHT / 2
    @radius   = 20
    @velocity = 0
  end

  # Apply gravity each update, and move the bird down (increase y).
  def update
    @velocity += FlappyBird::GRAVITY
    @y += @velocity
  end

  # Flap sets velocity to a negative number so the bird goes up.
  def flap
    @velocity = FlappyBird::JUMP_POWER
  end

  # Draw our bird as a circle, colored yellow.
  def draw
    draw_circle(@x, @y, @radius, 32, Gosu::Color::YELLOW, 2)
  end
end

# -----------------------------------------------------------------------------
# Pipe Class
# -----------------------------------------------------------------------------
#
# Each pipe has an x,y position, a width, and a height. It's either a top pipe
# or bottom pipe depending on the y coordinate.
#
class Pipe
  attr_reader :x, :y, :width, :height
  attr_accessor :scored  # We'll mark the top pipe scored once the bird passes.

  def initialize(window, x, y, height)
    @window = window
    @x      = x
    @y      = y
    @width  = FlappyBird::PIPE_WIDTH
    @height = height
    @scored = false
  end

  # Move the pipe left by a certain speed.
  def update(speed)
    @x -= speed
  end

  # Draw the pipe as a green rectangle.
  def draw
    draw_rect(@x, @y, @width, @height, Gosu::Color::GREEN, 1)
  end
end

# -----------------------------------------------------------------------------
# Start the Game
# -----------------------------------------------------------------------------
FlappyBird.new.show
