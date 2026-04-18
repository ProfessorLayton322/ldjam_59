# Project Notes

## Graph Resource

Added a Godot 4 graph resource under ludum-dare-59/scripts/resources/ for parsed/runtime data, not editor-authored data:

- graph.gd defines Graph, a Resource with nodes: Array[GraphVertex]. The nodes array is a plain var and is intentionally not exported.
- graph_vertex.gd defines GraphVertex, a RefCounted data object with plain vars id: int, position: Vector2, and neighbour_ids: Array[int]. Nothing is exported.
- The vertex type is named GraphVertex instead of the previous node-style name to avoid colliding with Godot/system node naming.
- Graph.build_from_grid(size: Vector2i, tile_size: Vector2, origin: Vector2 = Vector2.ZERO) creates one vertex per 2D grid cell.
- Vertex IDs are stable row-major integers: id = y * width + x.
- Vertex positions are tile centers: origin + Vector2((x + 0.5) * tile_size.x, (y + 0.5) * tile_size.y).
- Neighbour IDs are stored for existing orthogonal neighbours only, in bottom, top, left, right order, so each vertex has at most four neighbours.

Godot generated and should keep these UID files:

- ludum-dare-59/scripts/resources/graph.gd.uid
- ludum-dare-59/scripts/resources/graph_vertex.gd.uid

## Verification

Verify resource script registration by opening the Godot project headlessly and quitting:

    cd ludum-dare-59
    godot --headless --editor --quit

Expected useful signal: Godot registers global classes Graph and GraphVertex, then exits with code 0. The current project may also print unrelated godot_mcp warnings or shutdown script errors from the addon; those are not caused by the graph resource scripts.

