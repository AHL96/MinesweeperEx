"""
TODOs:
[ ] validate choice
[ ] add bomb flagging
[ ] reveal all bombs when game is lost
[ ] let player know when they've won
[ ] impliment to_string on Minesweeper
"""

defmodule Cell do
  defstruct visible?: false,
            bomb?: false,
            neighboring_bomb_count: 0,
            letter: nil,
            number: nil,
            flagged?: false,
            selected?: false

  def new(args) do
    %Cell{
      visible?: false,
      bomb?: make_bomb?(),
      neighboring_bomb_count: 0,
      flagged?: false,
      selected?: false,
      letter: args.letter,
      number: args.number
    }
  end

  def make_bomb?(rate \\ 0.1) do
    :rand.uniform() <= rate
  end

  def select(%Cell{visible?: false} = cell) do
    %Cell{cell | visible?: true}
  end

  def get_location(%Cell{letter: letter, number: number}) do
    {letter, number}
  end
end

defimpl String.Chars, for: Cell do
  # def to_string(%Cell{visible?: false, bomb?: true}), do: "_"
  def to_string(%Cell{visible?: false}), do: "#"
  def to_string(%Cell{visible?: false, flagged?: true}), do: "F"
  def to_string(%Cell{visible?: false, selected?: true}), do: "X"
  def to_string(%Cell{visible?: true, bomb?: true}), do: "@"
  def to_string(%Cell{visible?: true, bomb?: false, neighboring_bomb_count: 0}), do: " "

  def to_string(%Cell{visible?: true, bomb?: false, neighboring_bomb_count: count}),
    do: "#{count}"
end

defmodule Minesweeper do
  defstruct game_over?: false, board: Map.new()

  @letters ~c"abcdefghijklmnopqrstuvwxyz"
  @numbers Range.to_list(1..13)
  @locations Enum.flat_map(@numbers, fn n ->
               Enum.map(@letters, fn letter -> {letter, n} end)
             end)

  def new() do
    %Minesweeper{}
    |> fill
    |> tally_numbers
    |> start
  end

  def fill(%Minesweeper{} = game) do
    filled_board =
      Enum.map(@locations, fn {letter, number} = loc ->
        {loc, Cell.new(%{letter: letter, number: number})}
      end)

    %Minesweeper{game | board: Map.new(filled_board)}
  end

  def tally_numbers(%Minesweeper{board: board} = game) do
    updated_board =
      board
      |> Stream.filter(fn {_, cell} -> cell.bomb? end)
      |> Enum.reduce(board, fn {_loc, cell}, changes ->
        updated_game = %Minesweeper{game | board: changes}
        Map.merge(changes, increamented_neightbors(updated_game, cell))
      end)

    %Minesweeper{game | board: updated_board}
  end

  def increamented_neightbors(%Minesweeper{} = game, %Cell{bomb?: true} = cell) do
    get_neighbors(game, cell)
    |> Enum.reduce(%{}, fn {loc, neighbor}, changes ->
      Map.put(changes, loc, increament_bomb_count(neighbor))
    end)
  end

  def get_neighbors(%Minesweeper{board: board}, %Cell{} = cell) do
    get_neighbor_locs(cell)
    |> Enum.reduce(%{}, &Map.put(&2, &1, board[&1]))
  end

  def get_neighbor_locs(%Cell{letter: letter, number: number}) do
    possible_neightbor_locs = [
      {letter - 1, number - 1},
      {letter, number - 1},
      {letter + 1, number - 1},
      {letter - 1, number},
      {letter + 1, number},
      {letter - 1, number + 1},
      {letter, number + 1},
      {letter + 1, number + 1}
    ]

    Enum.filter(possible_neightbor_locs, &Enum.member?(@locations, &1))
  end

  def increament_bomb_count(%Cell{neighboring_bomb_count: count} = cell) do
    %Cell{cell | neighboring_bomb_count: count + 1}
  end

  def start(%Minesweeper{} = game) do
    update(game)
  end

  def update(%Minesweeper{game_over?: true} = game) do
    display_board(game)
    IO.puts("GAME OVER")
    {:error, "You selected a bomb! GAME OVER."}
  end

  def update(%Minesweeper{game_over?: false} = game) do
    display_board(game)
    spot = choose_spot(game)

    game
    |> reveal_spot(spot)
    |> update()
  end

  def reveal_spot(
        %Minesweeper{game_over?: false} = game,
        %Cell{visible?: false, bomb?: true} = cell
      ) do
    updated_game = make_visible(game, cell)
    %Minesweeper{updated_game | game_over?: true}
  end

  def reveal_spot(
        %Minesweeper{game_over?: false} = game,
        %Cell{visible?: true, bomb?: false}
      ) do
    game
  end

  def reveal_spot(
        %Minesweeper{} = game,
        %Cell{visible?: false, bomb?: false, neighboring_bomb_count: 0} = cell
      ) do
    neightbors = Map.values(get_neighbors(game, cell))

    game
    |> make_visible(cell)
    |> reveal_neighbors(neightbors)
  end

  def reveal_spot(
        %Minesweeper{} = game,
        %Cell{visible?: false, bomb?: false} = cell
      )
      when cell.neighboring_bomb_count > 0 do
    make_visible(game, cell)
  end

  def reveal_neighbors(%Minesweeper{} = game, []) do
    game
  end

  def reveal_neighbors(
        %Minesweeper{} = game,
        [%Cell{} = neighbor | rest]
      ) do
    game
    |> reveal_neighbors(rest)
    |> reveal_spot(neighbor)
  end

  def make_visible(
        %Minesweeper{board: board} = game,
        %Cell{visible?: false} = cell
      ) do
    selected_cell = Cell.select(cell)
    location = Cell.get_location(selected_cell)
    updated_board = Map.update!(board, location, fn _ -> selected_cell end)

    %Minesweeper{game | board: updated_board}
  end

  def choose_spot(%Minesweeper{board: board}) do
    letter = get_letter()
    number = get_number()

    loc = {letter, number}
    board[loc]
  end

  defp get_letter() do
    IO.gets("Select a letter: ")
    |> String.to_charlist()
    |> List.first()
  end

  defp get_number() do
    IO.gets("Select a number: ")
    |> String.trim()
    |> String.to_integer()
  end

  def display_board(%Minesweeper{board: board} = game) when is_map(board) do
    # update this to work with IO.puts().
    # defimpl String.Chars, for: Minesweeper do
    IO.write("\t ")
    IO.puts(@letters)

    Enum.each(@locations, fn {letter, number} = loc ->
      case letter do
        ?a ->
          IO.write("#{number}\t|" <> to_string(board[loc]))

        ?z ->
          IO.write(to_string(board[loc]) <> "|\n")

        _ ->
          IO.write(to_string(board[loc]))
      end
    end)

    IO.write("\n")
    game
  end
end

Minesweeper.new()
