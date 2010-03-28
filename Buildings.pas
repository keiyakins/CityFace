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
		Tex: Integer;
		Style: TPolyStyles;
	end;
	TPolies = array of TPolyData;

	TBuildingData = record
		PolyData: TPolies;
	end;

function CubistTumorBuilding: TBuildingData;
function GenericBuilding: TBuildingData;
procedure OffsetBuilding(var Wot: TBuildingData; Delta: T3Vector);
procedure RenderBuilding(const Wot: TBuildingData);




implementation

uses
	GL, GLD,
	Solvation, MTRandomity;

const
	WindowedTex: LongWord = 0;
	RoofTex: LongWord = 0;

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

procedure SetUVVars(U, V: Double);
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

procedure MakePoliesFromBlock(var Polies: TPolies; Block: TBlockData);
begin
	with Block do begin
		SetLength(Polies, 10);
		SetPoliesFromQuad(Polies[0], Polies[1], Vector(nX, nY, nZ), Vector(nX, nY, xZ), Vector(nX, xY, nZ), Vector(nX, xY, xZ), Vector(-1, 0, 0), '.5-Z/20', 'Y/20', WindowedTex, [psLit]);
		SetPoliesFromQuad(Polies[2], Polies[3], Vector(xX, nY, nZ), Vector(xX, nY, xZ), Vector(xX, xY, nZ), Vector(xX, xY, xZ), Vector(+1, 0, 0), '.5+Z/20', 'Y/20', WindowedTex, [psLit]);
		SetPoliesFromQuad(Polies[4], Polies[5], Vector(nX, nY, xZ), Vector(xX, nY, xZ), Vector(nX, xY, xZ), Vector(xX, xY, xZ), Vector(0, 0, +1), '.5-X/20', 'Y/20', WindowedTex, [psLit]);
		SetPoliesFromQuad(Polies[6], Polies[7], Vector(nX, nY, nZ), Vector(xX, nY, nZ), Vector(nX, xY, nZ), Vector(xX, xY, nZ), Vector(0, 0, -1), '.5+X/20', 'Y/20', WindowedTex, [psLit]);
		SetPoliesFromQuad(Polies[8], Polies[9], Vector(nX, xY, nZ), Vector(nX, xY, xZ), Vector(xX, xY, nZ), Vector(xX, xY, xZ), Vector(0, +1, 0), '.5+X/20', '.5-Z/20', RoofTex, [psLit]);
	end;
end;

function CubistTumorBuilding: TBuildingData;

	function Perturb(N: TReal): TReal;
	begin
		Result := Round((RandReal + 1)/3 * N);
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

var
	CoreBlock, ThisBlock: TBlockData;
	ThisBlockPolies: TPolies;

begin
	CoreBlock.nX := -9 + RandN(7);
	CoreBlock.xX := +9 - RandN(7);
	CoreBlock.nY := 0;
	CoreBlock.xY := +64 - RandN(7);
	CoreBlock.nZ := -9 + RandN(7);
	CoreBlock.xZ := +9 - RandN(7);
	MakePoliesFromBlock(Result.PolyData, CoreBlock);
	ThisBlock.nY := 0;
	ThisBlock.nX := -10;
	ThisBlock.xX := CoreBlock.nX;
	ThisBlock.xY := Perturb(CoreBlock.xY);
	ThisBlock.nZ := Perturb(CoreBlock.nZ);
	ThisBlock.xZ := Perturb(CoreBlock.xZ);
	MakePoliesFromBlock(ThisBlockPolies, ThisBlock);
	CullFacing(ThisBlockPolies, Vector(+1, 0, 0));
	AppendPolies(Result.PolyData, ThisBlockPolies);

	ThisBlock.nX := CoreBlock.xX;
	ThisBlock.xX := +10;
	ThisBlock.xY := Perturb(CoreBlock.xY);
	ThisBlock.nZ := Perturb(CoreBlock.nZ);
	ThisBlock.xZ := Perturb(CoreBlock.xZ);
	MakePoliesFromBlock(ThisBlockPolies, ThisBlock);
	CullFacing(ThisBlockPolies, Vector(-1, 0, 0));
	AppendPolies(Result.PolyData, ThisBlockPolies);

	ThisBlock.nX := Perturb(CoreBlock.nX);
	ThisBlock.xX := Perturb(CoreBlock.xX);
	ThisBlock.xY := Perturb(CoreBlock.xY);
	ThisBlock.nZ := -10;
	ThisBlock.xZ := CoreBlock.nZ;
	MakePoliesFromBlock(ThisBlockPolies, ThisBlock);
	CullFacing(ThisBlockPolies, Vector(0, 0, +1));
	AppendPolies(Result.PolyData, ThisBlockPolies);

	ThisBlock.nX := Perturb(CoreBlock.nX);
	ThisBlock.xX := Perturb(CoreBlock.xX);
	ThisBlock.xY := Perturb(CoreBlock.xY);
	ThisBlock.nZ := CoreBlock.nZ;
	ThisBlock.xZ := +10;
	MakePoliesFromBlock(ThisBlockPolies, ThisBlock);
	CullFacing(ThisBlockPolies, Vector(0, 0, -1));
	AppendPolies(Result.PolyData, ThisBlockPolies);

	SetLength(ThisBlockPolies, 0);
end;

function GenericBuilding: TBuildingData;
var
	ThisBlock: TBlockData;

begin
	ThisBlock.nX := -10;
	ThisBlock.xX := +10;
	ThisBlock.xY := Round(34 - RandReal*30);
	ThisBlock.nZ := -10;
	ThisBlock.xZ := +10;
	MakePoliesFromBlock(Result.PolyData, ThisBlock);
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

end.
