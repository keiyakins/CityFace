unit BuildScripts;

interface

uses
	DUtils, D3Vectors, Buildings, Solvation;

var
	FactionType: array of TFactionType;
	Faction: array of TFaction;
	NeighborhoodType: array of TNeighborhoodType;
	Neighborhood: array of TNeighborhood;



procedure LoadBuildScript;
function BuildNeighborhoodFromType(NT: TNeighborhoodType): TNeighborhood;





implementation

uses
	Math, Randomity, SysUtils;

var
	BuildLog: String;

procedure Log(S: String);
begin
	BuildLog := BuildLog + S + #13#10;
end;

type
	TParsedAction = record
		bAssignment: Boolean;
		LValue, RValue: String;
		SubScript: TStringArray;
	end;
	TParsedActionArray = array of TParsedAction;

function DumpFileToStringArray(FN: String; bIncludeEmpties: Boolean = True): TStringArray;
var
	Buf: String;
	I, J, oJ: Integer;

begin
	Buf := DumpFileToString('Build.cfs') + #0;
	//Convert CRLFs, CRs, and LFs to NULs.
	Buf := StringReplace(Buf, #13#10, #0, [rfReplaceAll]);
	Buf := StringReplaceC(Buf, #13, #0);
	Buf := StringReplaceC(Buf, #10, #0);
	J := 0;
	for I := 1 to Length(Buf) do if Buf[I] = #0 then Inc(J);
	SetLength(Result, J);
	I := 0;
	oJ := 1;
	for J := 1 to Length(Buf) do if Buf[J] = #0 then begin
		if (J > oJ) or bIncludeEmpties then begin
			Result[I] := Copy(Buf, oJ, J - oJ);
			Inc(I);
		end;
		oJ := J + 1;
	end;
	SetLength(Result, I);
	//We injected a line-end at the end, so there's no trailing line to deal with.
	Buf := '';
end;

function GetTabLevel(S: String): Integer;
var
	I: Integer;

begin
	for I := 1 to Length(S) do
		if S[I] <> #9 then begin
			Result := I - 1;
			Exit;
		end
	;
	Result := Length(S);
end;

function ExtractContinue(var S: String): Boolean;
begin
	Result := S[Length(S)] = ':';
	if Result then SetLength(S, Length(S)-1);
end;

procedure AddStr(var A: TStringArray; S: String);
var
	I: Integer;

begin
	I := Length(A);
	SetLength(A, I + 1);
	A[I] := S;
end;

function GetSubScript(FromScript: TStringArray; var NextIndex: Integer; ParentTabLevel: Integer; ParentType, ParentNom: String): TStringArray;
var
	Lin2, Lin2A: String;
	I: Integer;

begin
	SetLength(Result, 0);
	while (NextIndex < Length(FromScript)) and (GetTabLevel(FromScript[NextIndex]) > ParentTabLevel) do begin
		AddStr(Result, FromScript[NextIndex]);
		Inc(NextIndex);
	end;
	if NextIndex < Length(FromScript) then begin
		Lin2 := FromScript[NextIndex];
		if GetTabLevel(Lin2) = ParentTabLevel then begin
			Lin2 := Trim(Lin2);
			I := Pos(' ', Lin2);
			if I = 0 then begin
				Lin2A := '';
			end
			else begin
				Lin2A := UpperCase(Trim(Copy(Lin2, I + 1, MAXINT)));
				Lin2 := UpperCase(Trim(Copy(Lin2, 1, I - 1)));
			end;
			if Lin2 = 'END' then begin
				Inc(NextIndex);
				if (Length(Lin2A) <> 0) and (Lin2A <> ParentType) then
					Log('Build script warning: end specifier "' + Lin2A + '" did not match "' + ParentType + '" on ' + ParentNom + '.')
				;
			end;
		end;
	end;
end;

function ParseScript(Script: TStringArray): TParsedActionArray;
var
	I, LI, NextLI: Integer;
	ThisTabLevel: Integer;
	Lin: String;
	bContinues: Boolean;

begin
	SetLength(Result, 0);
	LI := 0;
	while LI <= High(Script) do begin
		NextLI := LI + 1;
		Lin := Script[LI];
		ThisTabLevel := GetTabLevel(Lin);
		Lin := Trim(Lin);
		bContinues := ExtractContinue(Lin);

		I := Length(Result);
		SetLength(Result, I+1);
		with Result[I] do begin
			I := Pos('=', Lin);
			bAssignment := I <> 0;
			if bAssignment then begin
				LValue := UpperCase(Trim(Copy(Lin, 1, I - 1)));
				RValue := Trim(Copy(Lin, I + 1, MAXINT));
				if bContinues then
					SubScript := GetSubScript(Script, NextLI, ThisTabLevel, LValue, RValue)
				else
					SetLength(SubScript, 0)
				;
			end
			else begin
				LValue := Lin;
				RValue := '';
			end;
		end;

		LI := NextLI;
	end;
end;

function FTFromScript(ScriptLin: TStringArray; NewNom: String): TFactionType;
var
	PAI: Integer;
	ParsedAction: TParsedActionArray;

begin
	Result := TFactionType.Create;
	Result.Nom := NewNom;
	ParsedAction := ParseScript(ScriptLin);

	for PAI := 0 to High(ParsedAction) do with ParsedAction[PAI] do begin
		if bAssignment then begin
			Log('Build script warning: unrecognized assignment "' + LValue + ' = ' + RValue + '" in FactionType ' + Result.Nom + '.');
		end
		else begin //Directive.
			Log('Build script warning: unrecognized directive "' + LValue + '" in FactionType ' + Result.Nom + '.');
		end;
	end;
end;

function FFromScript(ScriptLin: TStringArray; NewNom: String): TFaction;
var
	I, PAI: Integer;
	ParsedAction: TParsedActionArray;
	UT: String;

begin
	Result := TFaction.Create;
	Result.Nom := NewNom;
	ParsedAction := ParseScript(ScriptLin);

	for PAI := 0 to High(ParsedAction) do with ParsedAction[PAI] do begin
		if bAssignment then begin
			if LValue = 'TYPE' then begin
				Result.FactionType := nil; //Needs a for/else; use of a sentinel is a hack.
				UT := UpperCase(RValue);
				for I := 0 to High(FactionType) do
					if UpperCase(FactionType[I].Nom) = UT then begin
						Result.FactionType := FactionType[I];
						Break;
					end
				;
				if Result.FactionType = nil then
					Log('Build script warning: unrecognized faction type "' + RValue + '" in Faction ' + Result.Nom + '.')
				;
			end
			else begin
				Log('Build script warning: unrecognized assignment "' + LValue + ' = ' + RValue + '" in Faction ' + Result.Nom + '.');
			end;
		end
		else begin //Directive.
			Log('Build script warning: unrecognized directive "' + LValue + '" in Faction ' + Result.Nom + '.');
		end;
	end;
end;

function BTFromScript(ScriptLin: TStringArray; NewNom: String): TBuildingType;
var
	PAI: Integer;
	ParsedAction: TParsedActionArray;

	ActivityMain, ActivitySub, UT: String;
	GI, I: Integer;
	GearToken: TStringArray;

begin
	Result := TBuildingType.Create;
	Result.Nom := NewNom;
	Result.Common := 1;
	Result.PriceFactor := 1;
	Result.bSINlessOK := RandBit;
	Result.BuildFunc := GenericBuilding;
	ParsedAction := ParseScript(ScriptLin);

	for PAI := 0 to High(ParsedAction) do with ParsedAction[PAI] do begin
		if bAssignment then begin
			if LValue = 'COMMON' then try
				Result.Common := Round(Solve(RValue));
			except
				Log('Build script warning: invalid Common "' + RValue + '" in BuildingType ' + Result.Nom + '.');
			end
			else if LValue = 'PRICEFACTOR' then try
				Result.PriceFactor := Solve(RValue);
			except
				Log('Build script warning: invalid PriceFactor "' + RValue + '" in BuildingType ' + Result.Nom + '.');
			end
			else if LValue = 'SINLESSOK' then begin
				if UpperCase(RValue) = 'TRUE' then
					Result.bSINlessOK := True
				else if UpperCase(RValue) = 'FALSE' then
					Result.bSINlessOK := False
				else
					Log('Build script warning: invalid SINlessOK "' + RValue + '" in BuildingType ' + Result.Nom + '.')
				;
			end
			else if LValue = 'FUNC' then begin
				if UpperCase(RValue) = 'CUBISTTUMORBUILDING' then
					Result.BuildFunc := CubistTumorBuilding
				else if UpperCase(RValue) = 'GENSKYSCRAPERBUILDING' then
					Result.BuildFunc := GenSkyscraperBuilding
				else if UpperCase(RValue) = 'GENERICBUILDING' then
					Result.BuildFunc := GenericBuilding
				else if UpperCase(RValue) = 'PARKINGBUILDING' then
					Result.BuildFunc := ParkingBuilding
				else if UpperCase(RValue) = 'SMALLPARKBUILDING' then
					Result.BuildFunc := SmallParkBuilding
				else
					Log('Build script warning: invalid Func "' + RValue + '" in BuildingType ' + Result.Nom + '.')
				;
			end
			else if LValue = 'FACTIONBASE' then begin
				Result.FactionBase := nil; //Needs a for/else; use of a sentinel is a hack.
				UT := UpperCase(RValue);
				for I := 0 to High(FactionType) do
					if UpperCase(FactionType[I].Nom) = UT then begin
						Result.FactionBase := FactionType[I];
						Break;
					end
				;
				if Result.FactionBase = nil then
					Log('Build script warning: unrecognized FactionBase "' + RValue + '" in BuildingType ' + Result.Nom + '.')
				;
			end
			else if LValue = 'FACTIONLINK' then begin
				Result.FactionLink := nil; //Needs a for/else; use of a sentinel is a hack.
				UT := UpperCase(RValue);
				for I := 0 to High(Faction) do
					if UpperCase(Faction[I].Nom) = UT then begin
						Result.FactionLink := Faction[I];
						Break;
					end
				;
				if Result.FactionLink = nil then
					Log('Build script warning: unrecognized FactionLink "' + RValue + '" in BuildingType ' + Result.Nom + '.')
				;
			end
			else if LValue = 'ACTIVITY' then begin
				if Length(RValue) = 0 then begin
					Result.Activity := acNone;
					Result.ShopGear := [];
				end
				else begin
					I := Pos('(', RValue);
					if (I <> 0) and (RValue[Length(RValue)] = ')') then begin
						ActivityMain := UpperCase(Trim(Copy(RValue, 1, I - 1)));
						ActivitySub := Trim(Copy(RValue, I + 1, Length(RValue) - I - 1));
					end
					else begin
						ActivityMain := UpperCase(RValue);
						ActivitySub := '';
					end;

					if ActivityMain = 'SLEEP' then begin
						Result.Activity := acSleep;
						Result.ShopGear := [];
					end
					else if ActivityMain = 'HEAL' then begin
						Result.Activity := acHeal;
						Result.ShopGear := [];
					end
					else if ActivityMain = 'SHOP' then begin
						Result.Activity := acShop;
						Result.ShopGear := [];
						GearToken := StrTokenize(ActivitySub, ',');
						for GI := 0 to High(GearToken) do begin
							ActivitySub := Trim(GearToken[GI]);
							if UpperCase(ActivitySub) = 'WEAPON' then
								Include(Result.ShopGear, gtWeapon)
							else if UpperCase(ActivitySub) = 'VEHICLE' then
								Include(Result.ShopGear, gtVehicle)
							else
								Log('Build script warning: invalid shop gear token "' + ActivitySub + '"(in Activity "' + RValue + '") in BuildingType ' + Result.Nom + '.')
							;
						end;
					end
					else
						Log('Build script warning: invalid Activity "' + RValue + '" in BuildingType ' + Result.Nom + '.')
					;
				end;
			end
			else begin
				Log('Build script warning: unrecognized assignment "' + LValue + ' = ' + RValue + '" in BuildingType ' + Result.Nom + '.');
			end;
		end
		else begin //Directive.
			Log('Build script warning: unrecognized directive "' + LValue + '" in BuildingType ' + Result.Nom + '.');
		end;
	end;
end;

function NTFromScript(ScriptLin: TStringArray; NewNom: String): TNeighborhoodType;
var
	I, PAI: Integer;
	ParsedAction: TParsedActionArray;

	NewBuildingType: TBuildingType;

begin
	Result := TNeighborhoodType.Create;
	Result.Nom := NewNom;
	Result.BasePropertyValue := 128;
	ParsedAction := ParseScript(ScriptLin);

	for PAI := 0 to High(ParsedAction) do with ParsedAction[PAI] do begin
		if bAssignment then begin
			if LValue = 'BLOCKMERGESTART' then try
				Result.BlockMergeStart := Solve(RValue);
			except
				Log('Build script warning: invalid BlockMergeStart "' + RValue + '" in NeighborhoodType ' + Result.Nom + '.');
			end
			else if LValue = 'BLOCKMERGESUSTAIN' then try
				Result.BlockMergeSustain := Solve(RValue);
			except
				Log('Build script warning: invalid BlockMergeSustain "' + RValue + '" in NeighborhoodType ' + Result.Nom + '.');
			end
			else if LValue = 'BASEPROPERTYVALUE' then try
				Result.BasePropertyValue := Solve(RValue);
			except
				Log('Build script warning: invalid BasePropertyValue "' + RValue + '" in NeighborhoodType ' + Result.Nom + '.');
			end
			else if LValue = 'PROPERTYCENTERBOOST' then try
				Result.PropertyCenterBoost := Solve(RValue);
			except
				Log('Build script warning: invalid PropertyCenterBoost "' + RValue + '" in NeighborhoodType ' + Result.Nom + '.');
			end
			else if LValue = 'BUILDINGTYPE' then begin
				NewBuildingType := BTFromScript(SubScript, RValue);
				I := Length(Result.BuildingType);
				SetLength(Result.BuildingType, I+1);
				Result.BuildingType[I] := NewBuildingType;
				Inc(Result.TotCommon, NewBuildingType.Common);
			end
			else begin
				Log('Build script warning: unrecognized assignment "' + LValue + ' = ' + RValue + '" in NeighborhoodType ' + Result.Nom + '.');
			end;
		end
		else begin //Directive.
			Log('Build script warning: unrecognized directive "' + LValue + '" in NeighborhoodType ' + Result.Nom + '.');
		end;
	end;
end;

procedure LoadBuildScript;
var
	I, PAI: Integer;
	ParsedAction: TParsedActionArray;

	NewFactionType: TFactionType;
	NewFaction: TFaction;
	NewNeighborhoodType: TNeighborhoodType;

begin
	ParsedAction := ParseScript(DumpFileToStringArray('Build.cfs', False));

	for PAI := 0 to High(ParsedAction) do with ParsedAction[PAI] do begin
		if bAssignment then begin
			if LValue = 'FACTIONTYPE' then begin
				NewFactionType := FTFromScript(SubScript, RValue);
				I := Length(FactionType);
				SetLength(FactionType, I+1);
				FactionType[I] := NewFactionType;
			end
			else if LValue = 'FACTION' then begin
				NewFaction := FFromScript(SubScript, RValue);
				I := Length(Faction);
				SetLength(Faction, I+1);
				Faction[I] := NewFaction;
			end
			else if LValue = 'NEIGHBORHOODTYPE' then begin
				NewNeighborhoodType := NTFromScript(SubScript, RValue);
				I := Length(NeighborhoodType);
				SetLength(NeighborhoodType, I+1);
				NeighborhoodType[I] := NewNeighborhoodType;
			end
			else begin
				Log('Build script warning: unrecognized assignment "' + LValue + ' = ' + RValue + '".');
			end;
		end
		else begin //Directive.
			Log('Build script warning: unrecognized directive "' + LValue + '".');
		end;
	end;

	DumpStringToFile(BuildLog, 'BuildLoad.log');
	BuildLog := '';
end;

function BuildNeighborhoodFromType(NT: TNeighborhoodType): TNeighborhood;
const
	ValuePivot = 10; //Half the max coordinate in a single direction.

var
	I, C, D, iX, iZ: Integer;

begin
	Result := TNeighborhood.Create;
	Result.NeighborhoodType := NT;
	for iX := Low(Result.CityBlock) to High(Result.CityBlock) do
		for iZ := Low(Result.CityBlock[iX]) to High(Result.CityBlock[iX]) do with Result.CityBlock[iX, iZ] do begin
			D := Max(Abs(iX), Abs(iZ)); //Manhattan distance from center.
			PropertyValue := Round(
				NT.BasePropertyValue + NT.PropertyCenterBoost*(ValuePivot - D)
			);

			BuildingType := nil; //Needs a for/else; use of a sentinel is a hack.
			C := RandN(NT.TotCommon);
			for I := 0 to High(NT.BuildingType) do begin
				Dec(C, NT.BuildingType[I].Common);
				if C < 0 then begin
					BuildingType := NT.BuildingType[I];
					Break;
				end;
			end;
			if BuildingType = nil then begin
				Log('Build warning: dropped off end of Building Type array in Neighborhood Type "' + NT.Nom + '". TotCommon > sum of Common? Picking one at random.');
				BuildingType := NT.BuildingType[RandN(Length(NT.BuildingType))];
			end;

			LinkedFaction := BuildingType.FactionLink;
			if BuildingType.FactionBase <> nil then begin
				LinkedFaction := TFaction.Create;
				with LinkedFaction do begin
					FactionType := BuildingType.FactionBase;
					Inc(FactionType.AutoIndex);
					Nom := FactionType.Nom + ' ' + IntToStr(FactionType.AutoIndex);
					//Log('Build debug: created faction "' + Nom + '".');
				end;
				I := Length(Faction);
				SetLength(Faction, I + 1);
				Faction[I] := LinkedFaction;
			end;

			Building := BuildingType.BuildFunc(Result.CityBlock[iX, iZ]);
			OffsetBuilding(Building, Vector(26*iX, 0, 26*iZ));
		end
	;

	DumpStringToFile(BuildLog, 'BuildEx.log');
	BuildLog := '';
end;

end.
