-- ORIGINALLY MADE BY omrezkeypie
-- Source: https://github.com/omrezkeypie/HashOctree/tree/main

--!optimize 2
--!native

type Object = {
	Position: Vector3,
}

export type HashQuadtree = {
	MaxDepth: number?,
	Size: number,
	OffsetPosition: Vector3?,
	Nodes: { { Object } },
}

type Module = {
	new: (Size: number, MaxDepth: number?, OffsetPosition: Vector3?) -> HashQuadtree,
	InsertObjects: (HashOctree: HashQuadtree, Objects: { Object }) -> (),
	QueryRect: (HashOctree: HashQuadtree, Position: Vector3, Size: Vector3) -> { Object },
	QueryCircle: (HashOctree: HashQuadtree, Position: Vector3, Radius: number) -> { Object },
	RemoveObject: (HashOctree: HashQuadtree, Object: Object) -> (),
	InsertObject: (HashOctree: HashQuadtree, Object: Object) -> (),
	VisualizeQuadtree: (HashOctree: HashQuadtree) -> (),
}

local SuffixToOrder = {
	Vector3.new(-1, 0, -1), --0
	Vector3.new(-1, 0, 1), --1
	Vector3.new(1, 0, -1), --6
	Vector3.new(1, 0, 1), --7
}

local Dot = Vector3.new().Dot
local SubdivideThreshold = 30

local HashOctreeModule: Module = {} :: Module

local function IsPositionInBox(Position: Vector3, MinBounds: Vector3, MaxBounds: Vector3): boolean
	return Position.X >= MinBounds.X
		and Position.X <= MaxBounds.X
		and Position.Z >= MinBounds.Z
		and Position.Z <= MaxBounds.Z
end

local function DetectBoxOverlap(
	MinBounds1: Vector3,
	MaxBounds1: Vector3,
	MinBounds2: Vector3,
	MaxBounds2: Vector3
): boolean
	return MinBounds1.X < MaxBounds2.X
		and MaxBounds1.X > MinBounds2.X
		and MinBounds1.Z < MaxBounds2.Z
		and MaxBounds1.Z > MinBounds2.Z
end

local function MagnitudeSquared(Position: Vector3): number
	return (Position.X * Position.X) + (Position.Z * Position.Z)
end

local function DetectRectAndCircleOverlap(
	MinBounds: Vector3,
	MaxBounds: Vector3,
	CircleCenter: Vector3,
	RadiusSquared: number
): boolean
	local ClosestPoint: Vector3
	do
		local Max = Vector3.new(math.max(CircleCenter.X, MinBounds.X), 0, math.max(CircleCenter.Z, MinBounds.Z))
		ClosestPoint = Vector3.new(math.min(Max.X, MaxBounds.X), 0, math.min(Max.Z, MaxBounds.Z))
	end
	--local ClosestPoint = SphereCenter:Max(MinBounds):Min(MaxBounds)
	local Distance = MagnitudeSquared(CircleCenter - ClosestPoint)

	return Distance <= RadiusSquared
end

local function Subdivide(HashOctree: HashQuadtree, Node: number)
	local ShiftedNode = Node * 4

	for i = 0, 3 do
		HashOctree.Nodes[ShiftedNode + i] = {}
	end
end

local function GetNodePositionAndSize(HashQuadtree: HashQuadtree, Node: number): (Vector2, Vector2)
	local NumberLength = math.max(32 - bit32.countlz(Node), 0) - 1
	local Position = Vector2.zero
	local HalfSize = HashQuadtree.Size / 4
	HalfSize = Vector2.new(HalfSize, HalfSize)

	for Index = 1, NumberLength, 2 do
		local Suffix = bit32.extract(Node, NumberLength - Index - 1, 2)

		Position = Position + (HalfSize * SuffixToOrder[Suffix + 1])

		Index += 2
		HalfSize = HalfSize / 2
	end

	return HashQuadtree.OffsetPosition + Position, HalfSize * 2
end

local function ReassignObjects(HashOctree: HashQuadtree, Node: number, NodePosition: Vector3)
	Subdivide(HashOctree, Node)

	local NodeTable = HashOctree.Nodes[Node]
	local ShiftedNode = Node * 4

	for i = 1, #NodeTable do
		local Object = NodeTable[i]
		local Position = Object.Position
		local Suffix = 0

		if Position.X > NodePosition.X then
			Suffix += 2
		end

		if Position.Z > NodePosition.Z then
			Suffix += 1
		end

		table.insert(HashOctree.Nodes[ShiftedNode + Suffix], Object)
	end

	table.clear(NodeTable)
end

function HashOctreeModule.new(Size: number, MaxDepth: number?, OffsetPosition: Vector3?): HashQuadtree
	local newHashOctree = {
		MaxDepth = if MaxDepth then math.clamp(MaxDepth, 1, 10) else 5,
		Size = Size,
		OffsetPosition = if OffsetPosition then OffsetPosition else Vector3.zero,
		Nodes = { {} },
	}

	return newHashOctree
end

function HashOctreeModule.InsertObjects(HashOctree: HashQuadtree, Objects: { Object })
	local QuarterSize = HashOctree.Size / 4
	local Size = QuarterSize
	local Depth = 0
	local NodePosition = HashOctree.OffsetPosition
	local ChosenNode = 1
	local MaxDepth = HashOctree.MaxDepth

	for _, Object in Objects do
		local Position = Object.Position

		while true do
			local Suffix = 0

			if Position.X > NodePosition.X then
				Suffix += 2
			end

			if Position.Z > NodePosition.Z then
				Suffix += 1
			end

			local NextNode = ChosenNode * 4 + Suffix

			if HashOctree.Nodes[NextNode] == nil then
				local ChosenNodeTable = HashOctree.Nodes[ChosenNode]

				table.insert(ChosenNodeTable, Object)

				if #ChosenNodeTable > SubdivideThreshold and Depth < MaxDepth then
					ReassignObjects(HashOctree, ChosenNode, NodePosition)
				end

				break
			end

			NodePosition = NodePosition + (Size * SuffixToOrder[Suffix + 1])

			Size = Size / 2
			ChosenNode = NextNode
			Depth = Depth + 1
		end

		Size = QuarterSize
		Depth = 0
		NodePosition = HashOctree.OffsetPosition
		ChosenNode = 1
	end
end

function HashOctreeModule.InsertObject(HashOctree: HashQuadtree, Object: Object)
	local Size = HashOctree.Size / 4
	local Depth = 0
	local NodePosition = HashOctree.OffsetPosition
	local ChosenNode = 1
	local MaxDepth = HashOctree.MaxDepth
	local Position = Object.Position

	while true do
		local Suffix = 0

		if Position.X > NodePosition.X then
			Suffix += 2
		end

		if Position.Z > NodePosition.Z then
			Suffix += 1
		end

		local NextNode = ChosenNode * 4 + Suffix

		if HashOctree.Nodes[NextNode] == nil then
			local ChosenNodeTable = HashOctree.Nodes[ChosenNode]

			table.insert(ChosenNodeTable, Object)

			if #ChosenNodeTable > SubdivideThreshold and Depth < MaxDepth then
				ReassignObjects(HashOctree, ChosenNode, NodePosition)
			end

			break
		end

		NodePosition = NodePosition + (Size * SuffixToOrder[Suffix + 1])

		Size = Size / 2
		ChosenNode = NextNode
		Depth = Depth + 1
	end
end

function HashOctreeModule.RemoveObject(HashOctree: HashQuadtree, Object: Object)
	local Size = HashOctree.Size / 4
	local ChosenNode = 1
	local NodePosition = HashOctree.OffsetPosition
	local Position = Object.Position

	while true do
		local Suffix = 0

		if Position.X > NodePosition.X then
			Suffix += 2
		end

		if Position.Z > NodePosition.Z then
			Suffix += 1
		end

		local NextNode = ChosenNode * 4 + Suffix

		if HashOctree.Nodes[NextNode] == nil then
			local LeafNode = HashOctree.Nodes[ChosenNode]
			table.remove(LeafNode, table.find(LeafNode, Object))

			break
		end

		NodePosition = NodePosition + (Size * SuffixToOrder[Suffix + 1])
		Size = Size / 2
		ChosenNode = NextNode
	end
end

function HashOctreeModule.QueryRect(HashOctree: HashQuadtree, Position: Vector3, Size: Vector3): { Object }
	local MinBound = Position - (Size / 2)
	local MaxBound = Position + (Size / 2)
	local ChosenNodes = { 1 }
	local Nodes = HashOctree.Nodes
	local GottenObjects = {}

	while #ChosenNodes > 0 do
		local Node = table.remove(ChosenNodes)
		local NodeTable = Nodes[Node]
		local NodePosition, NodeSize = GetNodePositionAndSize(HashOctree, Node)
		if not DetectBoxOverlap(MinBound, MaxBound, NodePosition - NodeSize, NodePosition + NodeSize) then
			continue
		end

		local ShifterNumber = Node * 4

		for HashSuffix = 0, 3 do
			local NextNode = ShifterNumber + HashSuffix

			if Nodes[NextNode] == nil then
				if #NodeTable > 0 then
					for _, Object in NodeTable do
						if not IsPositionInBox(Object.Position, MinBound, MaxBound) then
							continue
						end

						table.insert(GottenObjects, Object)
					end
				end

				break
			end

			table.insert(ChosenNodes, NextNode)
		end
	end

	return GottenObjects
end

function HashOctreeModule.QueryCircle(HashOctree: HashQuadtree, Position: Vector3, Radius: number): { Object }
	local ChosenNodes = { 1 }
	local Nodes = HashOctree.Nodes
	local GottenObjects = {}
	Radius *= Radius

	while #ChosenNodes > 0 do
		local Node = table.remove(ChosenNodes)
		local NodeTable = Nodes[Node]
		local NodePosition, NodeSize = GetNodePositionAndSize(HashOctree, Node)

		if not DetectRectAndCircleOverlap(NodePosition - NodeSize, NodePosition + NodeSize, Position, Radius) then
			continue
		end

		local ShifterNumber = Node * 4

		for HashSuffix = 0, 3 do
			local NextNode = ShifterNumber + HashSuffix

			if Nodes[NextNode] == nil then
				if #NodeTable > 0 then
					for _, Object in NodeTable do
						local SubtractedPositions = Position - Object.Position

						if Dot(SubtractedPositions, SubtractedPositions, SubtractedPositions) <= Radius then
							table.insert(GottenObjects, Object)
						end
					end
				end

				break
			end

			table.insert(ChosenNodes, NextNode)
		end
	end

	return GottenObjects
end

local function MakeVisualisePart(Size, MaxBound, Suffix)
	local MiddlePosition = MaxBound

	local VisualizePart = Instance.new("Part")
	VisualizePart.Parent = workspace
	VisualizePart.Position = MiddlePosition
	VisualizePart.Size = Vector3.new(Size, Size, Size)
	VisualizePart.Anchored = true
	VisualizePart.Transparency = 1
	VisualizePart.Name = Suffix

	local SelectionBox = Instance.new("SelectionBox")
	SelectionBox.Parent = VisualizePart
	SelectionBox.Adornee = VisualizePart
end

function HashOctreeModule.VisualizeQuadtree(HashOctree: HashQuadtree)
	local UnvisualisedNodes = { { 1, Size = HashOctree.Size } }

	while #UnvisualisedNodes > 0 do
		local Node = table.remove(UnvisualisedNodes)
		local NodePosition = GetNodePositionAndSize(HashOctree, Node[1])

		MakeVisualisePart(Node.Size, NodePosition, Node[1])

		for i = 0, 7 do
			local HashIndex = Node[1] * 8 + i

			if HashOctree.Nodes[HashIndex] == nil then
				continue
			end

			table.insert(UnvisualisedNodes, { HashIndex, Size = Node.Size / 2 })
		end
	end
end

return HashOctreeModule
