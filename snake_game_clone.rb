require 'gosu'

class SnakeGame < Gosu::Window
  BLOCK_SIZE = 20           # Each cell is 20x20 pixels.
  INITIAL_MOVE_DELAY = 150  # Initial delay in milliseconds between moves.
  MIN_MOVE_DELAY = 50       # The fastest the snake can go.

  def initialize
    super 640, 480
    self.caption = "Snake Game"
    
    # Calculate grid dimensions.
    @grid_cols = width / BLOCK_SIZE
    @grid_rows = height / BLOCK_SIZE
    reset_game
  end

  def reset_game
    # (Re)initialize game state.
    @snake = Snake.new(@grid_cols / 2, @grid_rows / 2)
    @apple = Apple.new(rand(@grid_cols), rand(@grid_rows))
    reposition_apple
    @last_move_time = Gosu.milliseconds
    @score = 0
    @move_delay = INITIAL_MOVE_DELAY
    @game_over = false
  end

  def update
    if @game_over
      # Wait for the player to restart.
      if Gosu.button_down?(Gosu::KB_SPACE) || Gosu.button_down?(Gosu::KB_RETURN)
        reset_game
      end
      return
    end

    # Move the snake every @move_delay milliseconds.
    if Gosu.milliseconds - @last_move_time > @move_delay
      @snake.move
      check_collisions
      @last_move_time = Gosu.milliseconds
    end
  end

  def check_collisions
    # If the snake's head overlaps the apple, increase score, grow the snake, speed up the game, and reposition the apple.
    if @snake.head_x == @apple.x && @snake.head_y == @apple.y
      @snake.grow
      @score += 1
      # Increase speed as the score increases (but not beyond the minimum delay).
      @move_delay = [INITIAL_MOVE_DELAY - (@score * 2), MIN_MOVE_DELAY].max
      reposition_apple
    end

    # Check if the snake has collided with itself.
    if @snake.self_collision?
      @game_over = true
    end

    # Wrap the snake around if it goes off the grid.
    if @snake.head_x < 0 || @snake.head_x >= @grid_cols ||
       @snake.head_y < 0 || @snake.head_y >= @grid_rows
      @snake.wrap(@grid_cols, @grid_rows)
    end
  end

  def reposition_apple
    # Ensure the apple does not appear on the snake.
    begin
      new_x = rand(@grid_cols)
      new_y = rand(@grid_rows)
    end while @snake.occupies?(new_x, new_y)
    @apple.x = new_x
    @apple.y = new_y
  end

  def draw
    # Draw a black background.
    Gosu.draw_rect(0, 0, width, height, Gosu::Color::BLACK, 0)
    
    # Draw the apple.
    Gosu.draw_rect(@apple.x * BLOCK_SIZE, @apple.y * BLOCK_SIZE,
                   BLOCK_SIZE, BLOCK_SIZE, Gosu::Color::RED, 0)
    # Draw each segment of the snake.
    @snake.segments.each do |segment|
      Gosu.draw_rect(segment[0] * BLOCK_SIZE, segment[1] * BLOCK_SIZE,
                     BLOCK_SIZE, BLOCK_SIZE, Gosu::Color::GREEN, 0)
    end

    # Draw the current score.
    draw_text("Score: #{@score}", 10, 10, 1, Gosu::Color::WHITE)

    # If the game is over, display a game over message.
    if @game_over
      draw_text_centered("Game Over!", 40, Gosu::Color::YELLOW, offset: -20)
      draw_text_centered("Press Space or Enter to Restart", 20, Gosu::Color::GRAY, offset: 20)
    end
  end

  def draw_text(text, x, y, z, color)
    # Create a temporary font instance (for a more robust game you might cache this).
    Gosu::Font.new(20).draw_text(text, x, y, z, 1, 1, color)
  end

  def draw_text_centered(text, font_size, color, offset: 0)
    font = Gosu::Font.new(font_size)
    text_width = font.text_width(text)
    x = (width - text_width) / 2.0
    y = (height - font.height) / 2.0 + offset
    font.draw_text(text, x, y, 1, 1, 1, color)
  end

  def button_down(id)
    if @game_over
      # Also allow restarting via button press.
      reset_game if id == Gosu::KB_SPACE || id == Gosu::KB_RETURN
    else
      case id
      when Gosu::KB_UP    then @snake.change_direction(:up)
      when Gosu::KB_DOWN  then @snake.change_direction(:down)
      when Gosu::KB_LEFT  then @snake.change_direction(:left)
      when Gosu::KB_RIGHT then @snake.change_direction(:right)
      when Gosu::KB_ESCAPE then close
      end
    end
  end
end

class Snake
  attr_reader :segments

  def initialize(x, y)
    # The snake is represented as an array of [x, y] segments.
    @segments = [[x, y]]
    @direction = :right
    @grow_pending = 0
  end

  def head
    @segments.first
  end

  def head_x
    head[0]
  end

  def head_y
    head[1]
  end

  def move
    # Determine the new head position based on the current direction.
    dx, dy = direction_offset(@direction)
    new_head = [head_x + dx, head_y + dy]
    @segments.unshift(new_head)
    # If no growth is pending, remove the tail.
    if @grow_pending > 0
      @grow_pending -= 1
    else
      @segments.pop
    end
  end

  def grow
    # Each apple eaten schedules one growth unit.
    @grow_pending += 1
  end

  def change_direction(new_direction)
    # Prevent the snake from directly reversing.
    @direction = new_direction unless opposite_direction?(new_direction, @direction)
  end

  def self_collision?
    # Check if the head collides with any other segment.
    @segments[1..-1].include?(head)
  end

  def occupies?(x, y)
    # Check whether any segment occupies the given grid cell.
    @segments.any? { |seg| seg[0] == x && seg[1] == y }
  end

  def wrap(grid_cols, grid_rows)
    # Wrap the head position around the screen.
    new_head = [head_x % grid_cols, head_y % grid_rows]
    @segments[0] = new_head
  end

  private

  def direction_offset(dir)
    case dir
    when :up    then [0, -1]
    when :down  then [0, 1]
    when :left  then [-1, 0]
    when :right then [1, 0]
    else [0, 0]
    end
  end

  def opposite_direction?(dir1, dir2)
    (dir1 == :up    && dir2 == :down) ||
    (dir1 == :down  && dir2 == :up) ||
    (dir1 == :left  && dir2 == :right) ||
    (dir1 == :right && dir2 == :left)
  end
end

class Apple
  attr_accessor :x, :y

  def initialize(x, y)
    @x = x
    @y = y
  end
end

# Start the game.
SnakeGame.new.show
