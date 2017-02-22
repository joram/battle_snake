defmodule BattleSnake.DeathTest do
  alias BattleSnake.Death

  use BattleSnake.Case, async: true
  use BattleSnake.Point

  describe "Death.reap/1" do
    setup do
      snakes = [
        build(:snake, id: 0, coords: [p(1, 1)]),
        build(:snake, id: 1, coords: [p(0, 0), p(1, 0)], health_points: 0),
        build(:snake, id: 2, coords: [p(0, 0)]),
        build(:snake, id: 3, coords: [p(1, 0), p(2, 0), p(3, 0)]),
        build(:snake, id: 4, coords: [p(101, 0)]),
      ]

      world = build(:world, width: 100, height: 100, snakes: snakes)
      state = build(:state, world: world)

      state = Death.reap(state)

      [state: state]
    end

    test "updates who dies and who lives this turn", %{state: state} do
      live = state.world.snakes
      dead = state.world.dead_snakes
      assert [0] == (for x <- live, do: x.id)
      assert [1, 2, 3, 4] == (for x <- dead, do: x.id)
      assert [{1, [starvation: []]},
              {2, [collision: [collision_head: 1]]},
              {3, [collision: [collision_body: 1]]},
              {4, [wall_collision: []]}] == (for x <- dead, do: {x.id, x.cause_of_death})
    end
  end

  describe "Death.starvation/1" do
    setup do
      snakes =[build(:snake, id: :dead, health_points: 0),
               build(:snake, id: :alive, health_points: 100)]

      result = Death.starvation(snakes)

      [result: result]
    end

    test "kills snakes that starve this turn", %{result: {live, dead}} do
      assert [%{id: :dead}] = dead
      assert [%{id: :alive}] = live
    end

    test "sets the cause of death", %{result: {_live, dead}} do
      assert [starvation: []] == hd(dead).cause_of_death
    end
  end

  describe "Death.wall_collision/1" do
    setup do
      snakes =[
        build(:snake, id: 1, coords: [p(0, 0)]),
        build(:snake, id: 2, coords: [p(0, -1)]),
        build(:snake, id: 3, coords: [p(0, 100)]),
        build(:snake, id: 4, coords: [p(-1, 0)]),
        build(:snake, id: 5, coords: [p(100, 0)]),
      ]

      result = Death.wall_collision(snakes, {100, 100})

      [result: result]
    end

    test "kills snakes the hit a wall", %{result: {live, dead}} do
      assert [5, 4, 3, 2] == (for x <- dead, do: x.id)
      assert [1] == (for x <- live, do: x.id)
    end

    test "sets the cause of death", %{result: {_live, dead}} do
      assert [wall_collision: []] == hd(dead).cause_of_death
    end
  end

  describe "Death.collision/1" do
    setup do
      snakes =[
        build(:snake, id: 1, coords: [p(0, 0), p(1, 0), p(2, 0)]),
        build(:snake, id: 2, coords: [p(0, 0), p(1, 0)]),
        build(:snake, id: 3, coords: [p(0, 0), p(1, 0)]),
        build(:snake, id: 4, coords: [p(1, 0)])
      ]

      result = Death.collision(snakes)

      [result: result]
    end

    test "kills snakes the hit another snake", %{result: {live, dead}} do
      dead_ids = (for x <- dead, do: x.id)
      assert 2 in dead_ids
      assert 3 in dead_ids
      assert 4 in dead_ids
      assert length(dead_ids) == 3
      assert [%{id: 1}] = live
    end

    test "sets the cause of death", %{result: {_live, dead}} do
      assert [collision: _] = hd(dead).cause_of_death
    end

    test "sets who was collided with", %{result: {_live, dead}} do
      assert [{_, [collision_head: 1, collision_head: 3]}] = hd(dead).cause_of_death
    end
  end

  describe "Death.combine_dead/1" do
    setup do
      snakes = [
        s1 = build(:snake, id: 1),
        s2 = build(:snake, id: 2),
        s3 = build(:snake, id: 3),
        build(:snake, id: 4)
      ]

      cause_a = {:kill_a, []}
      cause_b = {:kill_b, []}
      cause_c = {:kill_c, []}

      l = [
        [%{s1|cause_of_death: [cause_a]}],
        [%{s1|cause_of_death: [cause_b]}, s2],
        [%{s1|cause_of_death: [cause_c]}, s3],
      ]

      result = Death.combine_dead(l)

      [result: result, snakes: snakes]
    end

    test "returns the union of the results", %{result: result} do
      assert is_list(result), inspect(result)
      assert [1, 2, 3] == (for x <- result, do: x.id)
    end

    test "merges the causes of death", %{result: result} do
      [s1|_] = result
      assert [kill_c: [], kill_b: [], kill_a: []] == s1.cause_of_death
    end
  end

  describe "Death.combine_live/1" do
    test "returns the intersection of the results" do
      [s1, s2, s3, s4] = build_list(4, :snake, id: sequence("snake"))

      l = [
        [s1, s2, s3],
        [s1, s3],
        [s3, s4],
      ]

      result = Death.combine_live(l)

      assert is_list result

      assert MapSet.new([s1, s3]) == result |> MapSet.new
    end
  end
end
