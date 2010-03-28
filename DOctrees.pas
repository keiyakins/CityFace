unit DOctrees;

interface

type
	TTerVoxel = type Byte;
const
	tvAir      : TTerVoxel = $00;
	tvRockBlack: TTerVoxel = $11;
	tvRockRed  : TTerVoxel = $12;

type
	PDOctreeNode = ^TDOctreeNode;
	TDOctreeNode = record
		ParentNode: PDOctreeNode;
	case bExpanded: Boolean of
		False: (TerVoxel: TTerVoxel);
		True: (SubNode: array[0..7] of PDOctreeNode);
	end;

	TDOctree = class
	protected
		FDimension: LongWord;
		RootNode: TDOctreeNode;
		function GetCell(X, Y, Z: LongWord): TTerVoxel; virtual;
		procedure SetCell(X, Y, Z: LongWord; NewCell: TTerVoxel); virtual;
	public
		function Reformat(NewDimension: LongWord; BlankVoxelType: TTerVoxel): Boolean; virtual;
		property Dimension: LongWord read FDimension;
		property Cell[X, Y, Z: LongWord]: TTerVoxel read GetCell write SetCell;
	end;





implementation

procedure DisposeDOctreeNode(Wot: PDOctreeNode);
var
	I: Integer;

begin
	with Wot^ do
		if bExpanded then
			for I := 0 to 7 do
				DisposeDOctreeNode(SubNode[I])
	;
	Dispose(Wot);
end;

function IsUniform(Node: PDOctreeNode): Boolean;
var
	I: Integer;
	BufTerVoxel: TTerVoxel;

begin
	//Result := True;
	//if not Node.bExpanded then Exit;

	Result := False;
	with Node.SubNode[0]^ do begin
		if bExpanded then Exit;
		BufTerVoxel := TerVoxel;
	end;
	for I := 1 to 7 do
		with Node.SubNode[I]^ do begin
			if bExpanded then Exit;
			if TerVoxel <> BufTerVoxel then Exit;
		end
	;

	Result := True;
end;

procedure SplitNode(Node: PDOctreeNode);
var
	I: Integer;
	BufTerVoxel: TTerVoxel;

begin
	with Node^ do begin
		if bExpanded then Exit;

		BufTerVoxel := TerVoxel;
		bExpanded := True;
		for I := 0 to 7 do
			New(SubNode[I])
		;
	end;
	for I := 0 to 7 do with Node.SubNode[I]^ do begin
		ParentNode := Node;
		TerVoxel := BufTerVoxel;
	end;
end;

procedure FoldNodeTo(Node: PDOctreeNode; NewVoxelType: TTerVoxel);
var
	I: Integer;

begin
	with Node^ do begin
		if bExpanded then begin
			for I := 0 to 7 do
				DisposeDOctreeNode(SubNode[I])
			;
			bExpanded := False;
		end;
		TerVoxel := NewVoxelType;
	end;
end;

{ TDOctree }

function TDOctree.GetCell(X, Y, Z: LongWord): TTerVoxel;
var
	ThisNode: PDOctreeNode;
	ThisDimension: LongWord;
	I: Integer;

begin
	ThisNode := @RootNode;
	ThisDimension := FDimension;
	while ThisNode.bExpanded do begin
		ThisDimension := ThisDimension shr 2;
		I := 0;
		if X >= ThisDimension then begin
			I := I or 1;
			X := X - ThisDimension;
		end;
		if Y >= ThisDimension then begin
			I := I or 2;
			Y := Y - ThisDimension;
		end;
		if Z >= ThisDimension then begin
			I := I or 4;
			Z := Z - ThisDimension;
		end;
		ThisNode := ThisNode.SubNode[I];
	end;
	Result := ThisNode.TerVoxel;
end;

procedure TDOctree.SetCell(X, Y, Z: LongWord; NewCell: TTerVoxel);
var
	ThisNode: PDOctreeNode;
	ThisDimension: LongWord;
	I: Integer;

begin
	ThisNode := @RootNode;
	ThisDimension := FDimension;
	while ThisNode.bExpanded do begin
		ThisDimension := ThisDimension shr 2;
		I := 0;
		if X >= ThisDimension then begin
			I := I or 1;
			X := X - ThisDimension;
		end;
		if Y >= ThisDimension then begin
			I := I or 2;
			Y := Y - ThisDimension;
		end;
		if Z >= ThisDimension then begin
			I := I or 4;
			Z := Z - ThisDimension;
		end;
		ThisNode := ThisNode.SubNode[I];
	end;
	if ThisNode.TerVoxel = NewCell then Exit;

	if ThisDimension > 1 then begin
		repeat
			SplitNode(ThisNode);
			ThisDimension := ThisDimension shr 2;
			I := 0;
			if X >= ThisDimension then begin
				I := I or 1;
				X := X - ThisDimension;
			end;
			if Y >= ThisDimension then begin
				I := I or 2;
				Y := Y - ThisDimension;
			end;
			if Z >= ThisDimension then begin
				I := I or 4;
				Z := Z - ThisDimension;
			end;
			ThisNode := ThisNode.SubNode[I];
		until ThisDimension <= 1;
		ThisNode.TerVoxel := NewCell;
	end
	else begin
		ThisNode.TerVoxel := NewCell;
		while (ThisNode.ParentNode <> nil) and IsUniform(ThisNode.ParentNode) do begin
			ThisNode := ThisNode.ParentNode;
			FoldNodeTo(ThisNode, NewCell);
		end;
	end;
end;

function TDOctree.Reformat(NewDimension: LongWord; BlankVoxelType: TTerVoxel): Boolean;
var
	DimBuf: LongWord;
	I: Integer;

begin
	Result := False;
	if NewDimension = 0 then Exit;

	//Make sure NewDimension is an integral power of two.
	I := 0;
	DimBuf := NewDimension shr 1;
	while DimBuf <> 0 do begin
		DimBuf := DimBuf shr 1;
		Inc(I);
	end;
	if NewDimension <> LongWord(1 shl I) then Exit;
	Result := True;

	FDimension := NewDimension;
	FoldNodeTo(@RootNode, BlankVoxelType);
end;

end.
