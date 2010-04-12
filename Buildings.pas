unit Buildings;

interface

uses
	D3Vectors, DUtils;

type
	TPolyStyle = (psLit, psSpecular);
	TPolyStyles = set of TPolyStyle;

	TVertexData = record
		Loc: T3Vector;
		U, V: TReal;
	end;

	TPolyData = record
		A, B, C: TVertexData;
		N: T3Vector;
		Tex: LongWord;
		Style: TPolyStyles;
	end;
	TPolies = array of TPolyData;

	TBuildingData = record
		PolyData: TPolies;
	end;

function CubistTumorBuilding: TBuildingData;
function GenericBuilding: TBuildingData;
function GenSkyscraperBuilding: TBuildingData;
function ParkingBuilding: TBuildingData;
procedure OffsetBuilding(var Wot: TBuildingData; Delta: T3Vector);
procedure RenderBuilding(const Wot: TBuildingData);
procedure RenderBuildingWithStyle(const Wot: TBuildingData; TarStyle: TPolyStyles);

var
	WindowedTex, RoofTex, ConcreteTex, SidewalkTex, AsphaltTex, BushyTex: LongWord;




implementation

uses
	Randomity,
	GL, GLD,
	Solvation;

type
	TBlockData = record
		nX, xX, nY, xY, nZ, xZ: TReal;
	end;

procedure SetVectorVars(V: T3Vector);
begin
	SetLength(VarList, 3);
	VarList[0].Nom := 'X';
	VarList[0].Value := V.X;
	VarList[1].Nom := 'Y';
	VarList[1].Value := V.Y;
	VarList[2].Nom := 'Z';
	VarList[2].Value := V.Z;
end;

procedure SetUVVars(U, V: TReal);
begin
	SetLength(VarList, 2);
	VarList[0].Nom := 'U';
	VarList[0].Value := U;
	VarList[1].Nom := 'V';
	VarList[1].Value := V;
end;

procedure AppendPolies(var ToPolies: TPolies; const FromPolies: TPolies);
var
	I, oL, dL: Integer;

begin
	oL := Length(ToPolies);
	dL := Length(FromPolies);
	SetLength(ToPolies, oL + dL);
	for I := 0 to dL - 1 do
		ToPolies[oL + I] := FromPolies[I]
	;
end;

procedure SetPoliesFromQuad(var PolyA, PolyD: TPolyData; ALoc, BLoc, CLoc, DLoc, MasterN: T3Vector; UEq, VEq: String; MasterTex: Integer; MasterStyle: TPolyStyles);
begin
	with PolyA do begin
		N := MasterN;
		A.Loc := ALoc;
		SetVectorVars(ALoc);
		A.U := Solve(UEq);
		A.V := Solve(VEq);
		B.Loc := BLoc;
		SetVectorVars(BLoc);
		B.U := Solve(UEq);
		B.V := Solve(VEq);
		C.Loc := CLoc;
		SetVectorVars(CLoc);
		C.U := Solve(UEq);
		C.V := Solve(VEq);
		Tex := MasterTex;
		Style := MasterStyle;
	end;
	PolyD := PolyA;
	with PolyD do begin
		A.Loc := DLoc;
		SetVectorVars(DLoc);
		A.U := Solve(UEq);
		A.V := Solve(VEq);
		Tex := MasterTex;
		Style := MasterStyle;
	end;
end;

procedure MakePoliesFromBlock(var Polies: TPolies; Block: TBlockData; bTop: Boolean = True; bBottom: Boolean = False);
begin
	with Block do begin
		SetLength(Polies, 10);
		SetPoliesFromQuad(Polies[0], Polies[1], Vector(nX, nY, nZ), Vector(nX, nY, xZ), Vector(nX, xY, nZ), Vector(nX, xY, xZ), Vector(-1, 0, 0), '.5-Z/20', 'Y/20', WindowedTex, []);
		SetPoliesFromQuad(Polies[2], Polies[3], Vector(xX, nY, nZ), Vector(xX, nY, xZ), Vector(xX, xY, nZ), Vector(xX, xY, xZ), Vector(+1, 0, 0), '.5+Z/20', 'Y/20', WindowedTex, []);
		SetPoliesFromQuad(Polies[4], Polies[5], Vector(nX, nY, xZ), Vector(xX, nY, xZ), Vector(nX, xY, xZ), Vector(xX, xY, xZ), Vector(0, 0, +1), '.5-X/20', 'Y/20', WindowedTex, []);
		SetPoliesFromQuad(Polies[6], Polies[7], Vector(nX, nY, nZ), Vector(xX, nY, nZ), Vector(nX, xY, nZ), Vector(xX, xY, nZ), Vector(0, 0, -1), '.5+X/20', 'Y/20', WindowedTex, []);
		SetPoliesFromQuad(Polies[8], Polies[9], Vector(nX, xY, nZ), Vector(nX, xY, xZ), Vector(xX, xY, nZ), Vector(xX, xY, xZ), Vector(0, +1, 0), '.5+X/20', '.5-Z/20', RoofTex, [psLit]);
	end;
end;

procedure CullFacing(var Polies: TPolies; FacingN: T3Vector);
var
	H, I: Integer;

begin
	H := High(Polies);
	for I := H downto 0 do with Polies[I] do
		if VDotProd(N, FacingN) > 0.9 then begin
			if I < H then Polies[I] := Polies[H];
			SetLength(Polies, H);
			Dec(H);
		end
	;
end;

procedure ConvertPoliesToSmallTex(var Polies: TPolies; SmallTex: LongWord);
var
	I: Integer;

begin
	for I := 0 to High(Polies) do begin
		Polies[I].Tex := SmallTex;
		Polies[I].Style := [psLit];
		with Polies[I].A do begin
			U := U*20;
			V := V*20;
		end;
		with Polies[I].B do begin
			U := U*20;
			V := V*20;
		end;
		with Polies[I].C do begin
			U := U*20;
			V := V*20;
		end;
	end;
end;

procedure MakeSidewalk(var Polies: TPolies);
var
	CoreBlock: TBlockData;

begin
	CoreBlock.nX := -11;
	CoreBlock.xX := +11;
	CoreBlock.nY := 0;
	CoreBlock.xY := +0.05;
	CoreBlock.nZ := -11;
	CoreBlock.xZ := +11;
	MakePoliesFromBlock(Polies, CoreBlock);
	ConvertPoliesToSmallTex(Polies, SidewalkTex);
end;

function CubistTumorBuilding: TBuildingData;

	function PerturbUp(N: TReal): TReal;
	begin
		Result := Round((RandReal*2 + 3)/6 * N);
	end;

	function PerturbSide(N: TReal): TReal;
	begin
		Result := Round((RandReal + 1)/3 * N);
	end;

var
	CoreBlock, ThisBlock: TBlockData;
	ThisBlockPolies: TPolies;

begin
	MakeSidewalk(Result.PolyData);

	CoreBlock.nX := -9 + Integer(RandN(7));
	CoreBlock.xX := +9 - Integer(RandN(7));
	CoreBlock.nY := 0;
	CoreBlock.xY := +64 - Integer(RandN(16));
	CoreBlock.nZ := -9 + Integer(RandN(7));
	CoreBlock.xZ := +9 - Integer(RandN(7));
	MakePoliesFromBlock(ThisBlockPolies, CoreBlock);
	AppendPolies(Result.PolyData, ThisBlockPolies);

	ThisBlock.nY := 0;
	ThisBlock.nX := -10;
	ThisBlock.xX := CoreBlock.nX;
	ThisBlock.xY := PerturbUp(CoreBlock.xY);
	ThisBlock.nZ := PerturbSide(CoreBlock.nZ);
	ThisBlock.xZ := PerturbSide(CoreBlock.xZ);
	MakePoliesFromBlock(ThisBlockPolies, ThisBlock);
	CullFacing(ThisBlockPolies, Vector(+1, 0, 0));
	AppendPolies(Result.PolyData, ThisBlockPolies);

	ThisBlock.nX := CoreBlock.xX;
	ThisBlock.xX := +10;
	ThisBlock.xY := PerturbUp(CoreBlock.xY);
	ThisBlock.nZ := PerturbSide(CoreBlock.nZ);
	ThisBlock.xZ := PerturbSide(CoreBlock.xZ);
	MakePoliesFromBlock(ThisBlockPolies, ThisBlock);
	CullFacing(ThisBlockPolies, Vector(-1, 0, 0));
	AppendPolies(Result.PolyData, ThisBlockPolies);

	ThisBlock.nX := PerturbSide(CoreBlock.nX);
	ThisBlock.xX := PerturbSide(CoreBlock.xX);
	ThisBlock.xY := PerturbUp(CoreBlock.xY);
	ThisBlock.nZ := -10;
	ThisBlock.xZ := CoreBlock.nZ;
	MakePoliesFromBlock(ThisBlockPolies, ThisBlock);
	CullFacing(ThisBlockPolies, Vector(0, 0, +1));
	AppendPolies(Result.PolyData, ThisBlockPolies);

	ThisBlock.nX := PerturbSide(CoreBlock.nX);
	ThisBlock.xX := PerturbSide(CoreBlock.xX);
	ThisBlock.xY := PerturbUp(CoreBlock.xY);
	ThisBlock.nZ := CoreBlock.xZ;
	ThisBlock.xZ := +10;
	MakePoliesFromBlock(ThisBlockPolies, ThisBlock);
	CullFacing(ThisBlockPolies, Vector(0, 0, -1));
	AppendPolies(Result.PolyData, ThisBlockPolies);

	SetLength(ThisBlockPolies, 0);
end;

function GenericBuilding: TBuildingData;
var
	ThisBlock: TBlockData;
	ThisBlockPolies: TPolies;

begin
	MakeSidewalk(Result.PolyData);

	ThisBlock.nX := -10;
	ThisBlock.xX := +10;
	ThisBlock.nY := 0;
	ThisBlock.xY := 24 - RandN(20);
	ThisBlock.nZ := -10;
	ThisBlock.xZ := +10;
	MakePoliesFromBlock(ThisBlockPolies, ThisBlock);
	AppendPolies(Result.PolyData, ThisBlockPolies);
end;

function GenSkyscraperBuilding: TBuildingData;
var
	ThisBlock: TBlockData;
	ThisBlockPolies: TPolies;

begin
	MakeSidewalk(Result.PolyData);

	ThisBlock.nX := -10;
	ThisBlock.xX := +10;
	ThisBlock.nY := 0;
	ThisBlock.xY := 48 - RandN(16);
	ThisBlock.nZ := -10;
	ThisBlock.xZ := +10;
	MakePoliesFromBlock(ThisBlockPolies, ThisBlock);
	AppendPolies(Result.PolyData, ThisBlockPolies);
end;

function ParkingBuilding: TBuildingData;
var
	ThisBlock: TBlockData;
	ThisBlockPolies: TPolies;
	I, S, Floors: Integer;

begin
	MakeSidewalk(Result.PolyData);

	Floors := 16 - RandN(14);

	for I := 0 to 3 do begin
		S := ((I and 1) * 2 - 1) * 9;
		ThisBlock.nX := S - 0.5;
		ThisBlock.xX := S + 0.5;
		ThisBlock.nY := 0;
		ThisBlock.xY := Floors*1.5;
		S := ((I and 2) - 1) * 9;
		ThisBlock.nZ := S - 0.5;
		ThisBlock.xZ := S + 0.5;
		MakePoliesFromBlock(ThisBlockPolies, ThisBlock);
		ConvertPoliesToSmallTex(ThisBlockPolies, ConcreteTex);
		AppendPolies(Result.PolyData, ThisBlockPolies);
	end;

	for I := 0 to Floors - 1 do begin
		ThisBlock.nX := -10;
		ThisBlock.xX := +10;
		ThisBlock.nY := I*1.5;
		ThisBlock.xY := I*1.5 + 0.5;
		ThisBlock.nZ := -10;
		ThisBlock.xZ := +10;
		MakePoliesFromBlock(ThisBlockPolies, ThisBlock, True, I > 0);
		ConvertPoliesToSmallTex(ThisBlockPolies, ConcreteTex);
		AppendPolies(Result.PolyData, ThisBlockPolies);
	end;
end;



procedure OffsetBuilding(var Wot: TBuildingData; Delta: T3Vector);
var
	I: Integer;

begin
	for I := 0 to High(Wot.PolyData) do with Wot.PolyData[I] do begin
		VADD(A.Loc, Delta);
		VADD(B.Loc, Delta);
		VADD(C.Loc, Delta);
	end;
end;

procedure RenderBuilding(const Wot: TBuildingData);
var
	I: Integer;
	LastTex: LongWord;
	LastStyle: TPolyStyles;
	bBegun: Boolean;

begin
	bBegun := False;
	LastTex := 0;
	LastStyle := [];
	for I := 0 to High(Wot.PolyData) do with Wot.PolyData[I] do begin
		if (not bBegun) or (Tex <> LastTex) or (Style <> LastStyle) then begin
			if bBegun then glEnd else bBegun := True;
			SetBoundTexture(Tex);
			LastTex := Tex;
			if psLit in Style then
				glEnable(GL_LIGHTING)
			else
				glDisable(GL_LIGHTING)
			;
			LastStyle := Style;
			glBegin(GL_TRIANGLES);
		end;
		with N do glNormal3f(X, Y, Z);
		with A do begin
			glTexCoord2f(U, V);
			with Loc do glVertex3f(X, Y, Z);
		end;
		with B do begin
			glTexCoord2f(U, V);
			with Loc do glVertex3f(X, Y, Z);
		end;
		with C do begin
			glTexCoord2f(U, V);
			with Loc do glVertex3f(X, Y, Z);
		end;
	end;
	if bBegun then glEnd;
end;

procedure RenderBuildingWithStyle(const Wot: TBuildingData; TarStyle: TPolyStyles);
var
	I: Integer;
	LastTex: LongWord;
	bBegun: Boolean;

begin
	bBegun := False;
	LastTex := 0;
	for I := 0 to High(Wot.PolyData) do with Wot.PolyData[I] do if Style = TarStyle then begin
		if (not bBegun) or (Tex <> LastTex) then begin
			if bBegun then glEnd else bBegun := True;
			SetBoundTexture(Tex);
			LastTex := Tex;
			glBegin(GL_TRIANGLES);
		end;
		with N do glNormal3f(X, Y, Z);
		with A do begin
			glTexCoord2f(U, V);
			with Loc do glVertex3f(X, Y, Z);
		end;
		with B do begin
			glTexCoord2f(U, V);
			with Loc do glVertex3f(X, Y, Z);
		end;
		with C do begin
			glTexCoord2f(U, V);
			with Loc do glVertex3f(X, Y, Z);
		end;
	end;
	if bBegun then glEnd;
end;

end.
