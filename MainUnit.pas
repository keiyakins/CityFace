unit MainUnit;

interface

uses
	SDL,
	SDLKeyDatas;

procedure FirstInit;
function GetSDLFlags: LongWord;
procedure InitGame;
procedure DoEvents;
function DoTime: LongWord;
procedure DoPhysics(dT: LongWord);
procedure DoGraphics;
procedure CleanupGame;

var
	LastTime: LongWord;
	Screen: PSDL_Surface;
	Done: Boolean = False;
	KeyData: TKeyData;





implementation

uses
	SysUtils, Math,
	Randomity,
	GL, GLD, GLImages,
	DUtils, D3Vectors,
	SpaceTextures,
	Buildings, BuildScripts;

type
	TFColor = record
		R, G, B: TReal;
	end;

	TPlayerData = record
		Loc, Facing: T3Vector;
		Speed: TReal;
	end;

	TCameraData = record
		Loc, Facing: T3Vector;
		MouseYaw, MousePitch: TReal;
		FM: array[0..15] of Single;
	end;

var
	Rot: TReal;
	Player: TPlayerData;
	Camera: TCameraData;
	FrameRate, SmoothedFrameRate: TReal;
	MouseSensitivity: TReal;
	bHasFocus: Boolean = True;

procedure FirstInit;
begin
end;

function GetSDLFlags: LongWord;
begin
	Result := SDL_INIT_VIDEO;
	//Flags := Flags or SDL_INIT_AUDIO;
end;

procedure GenProcTextures;
const
	kBlack: TRGBAColor = ( R: 0; G: 0; B: 0; A: 255 );

var
	ThisImage, ThatImage: TGLImage;
	I, X, Y, dX, dY, eX, eY: Integer;
	M, nM, ThatLight: TReal;
	C: TRGBAColor;
	Lights: array[0..19, 0..19] of TReal;

begin
	ThisImage := TGLImage.Create;
	ThatImage := TGLImage.Create;
	ThisImage.Resize(256, 256, kBlack);
	ThatImage.Resize(256, 256, kBlack);
	//Random seed.
	for Y := 0 to 255 do
		for X := 0 to 255 do
			ThatImage.GreyPixel[X, Y] := RandByte
	;
	//Blur.
	for Y := 0 to 255 do
		for X := 0 to 255 do
			ThisImage.GreyPixel[X, Y] :=
			( ThatImage.GreyPixel[X, Y]
			+ ThatImage.GreyPixel[Byte(X + 255), Y]
			+ ThatImage.GreyPixel[Byte(X + 1), Y]
			+ ThatImage.GreyPixel[X, Byte(Y + 255)]
			+ ThatImage.GreyPixel[X, Byte(Y + 1)]
			+ 2) div 5
	;
	RoofTex := ThisImage.BakeToL;

	//Darken.
	for Y := 0 to 255 do
		for X := 0 to 255 do
			ThatImage.GreyPixel[X, Y] := ThisImage.GreyPixel[X, Y] shr 2
	;
	AsphaltTex := ThatImage.BakeToL;

	//Green.
	C := kBlack;
	for Y := 0 to 255 do
		for X := 0 to 255 do begin
			C.G := ThisImage.Pixel[X, Y].G;
			ThatImage.Pixel[X, Y] := C;
		end
	;
	BushyTex := ThatImage.BakeToRGBA;
	FreeAndNil(ThatImage);

	//Lighten.
	for Y := 0 to 255 do
		for X := 0 to 255 do
			ThisImage.GreyPixel[X, Y] := (ThisImage.GreyPixel[X, Y] shr 1) or $80
	;
	ConcreteTex := ThisImage.BakeToL;

	//Bevel.
	for Y := 0 to 255 do
		for X := 0 to 7 do begin
			if X >= Y then Continue;
			if X >= 255-Y then Continue;
			M := X*(1/8);
			nM := 1 - M;
			ThisImage.GreyPixel[X, Y] := Round(ThisImage.GreyPixel[X, Y]*M + 255*nM);
			ThisImage.GreyPixel[255-X, Y] := Round(ThisImage.GreyPixel[255-X, Y]*M);
			//I know, it's kinda lame, but I already had everything calculated...
			ThisImage.GreyPixel[Y, X] := Round(ThisImage.GreyPixel[Y, X]*M + 255*nM);
			ThisImage.GreyPixel[Y, 255-X] := Round(ThisImage.GreyPixel[Y, 255-X]*M);
		end
	;
	for I := 0 to 7 do begin
		M := I*(1/8);
		nM := 1 - M;
		ThisImage.GreyPixel[I, I] := Round(ThisImage.GreyPixel[I, I]*M + 255*nM);
		ThisImage.GreyPixel[255-I, 255-I] := Round(ThisImage.GreyPixel[255-I, 255-I]*M);
	end;
	SidewalkTex := ThisImage.BakeToL;

	ThisImage.Resize(160*3, 160*3, kBlack);
	//Randomly assign light levels to windows.
	for Y := 0 to 19 do
		for X := 0 to 19 do
			Lights[X, Y] := RandReal
	;
	//Repeatedly blur adjacent-window light levels.
	for I := 1 to 6 do
		for Y := 0 to 19 do begin
			ThatLight := Lights[0, Y];
			for X := 0 to 18 do begin
				M := RandReal;
				nM := 1 - M;
				Lights[X, Y] := Lights[X, Y]*M + Lights[X+1, Y]*nM;
			end;
			M := RandReal;
			nM := 1 - M;
			Lights[19, Y] := Lights[19, Y]*M + ThatLight*nM;
		end
	;
	//Mostly snap to on or off.
	for Y := 0 to 19 do
		for X := 0 to 19 do
			Lights[X, Y] := Lights[X, Y]*0.4 + Ord(Lights[X, Y] >= 0.6)*0.6
	;
	//Final render. Upsampled for gluBuild2DMipmaps.
	for Y := 0 to 19 do
		for X := 0 to 19 do
			for dY := 3 to 6 do
				for dX := 1 to 6 do begin
					M := Lights[X, Y]*(dY-3)*(1/3);
					nM := Lights[X, Y]*(1 - M);
					with C do begin
						Color := (RandDWord and $01010101) * 255;
						R := (R + A) shr 1;
						G := (G + A) shr 1;
						B := (B + A) shr 1;
						R := Round(255*M + R*nM);
						G := Round(255*M + G*nM);
						B := Round(255*M + B*nM);
						A := 255;
					end;
					for eY := 0 to 2 do
						for eX := 0 to 2 do
							ThisImage.Pixel[(X*8+dX)*3+eX, (Y*8+dY)*3+eY] := C
					;
				end
	;
	WindowedTex := ThisImage.BakeToRGBA;
	FreeAndNil(ThisImage);
end;

procedure NewBuildings;
var
	iX, iZ: Integer;

begin
	if Length(Neighborhood) = 0 then begin
		SetLength(Neighborhood, 1);
		Neighborhood[0] := TNeighborhood.Create;
	end;

	with Neighborhood[0] do
		for iX := Low(CityBlock) to High(CityBlock) do
			for iZ := Low(CityBlock[iX]) to High(CityBlock[iX]) do
				with CityBlock[iX, iZ] do begin
					PropertyValue := 192 + RandN(20) - Abs(iX) - Abs(iZ);

					if PropertyValue > 200 then
						Building := CubistTumorBuilding()
					else if PropertyValue > 195 then
						Building := GenSkyscraperBuilding()
					else if PropertyValue = 191 then
						Building := SmallParkBuilding()
					else if PropertyValue = 190 then
						Building := ParkingBuilding()
					else
						Building := GenericBuilding()
					;
					OffsetBuilding(Building, Vector(26*iX, 0, 26*iZ));
				end
	;
end;

function ExtractMousePos: TPoint;
var
	X, Y, cX, cY: Integer;

begin
	cX := Screen.w div 2;
	cY := Screen.h div 2;
	SDL_GetMouseState(X, Y);
	SDL_WarpMouse(cX, cY);
	Result.X := X - cX;
	Result.Y := Y - cY;
end;

procedure InitGame;
const
	NearClip = 0.1;
	FarClip = NearClip * 20000;

var
	AspectRoot, iAspectRoot: TReal;

begin
	SDL_WM_SetCaption('Space', 'Space');

	//Reset the current viewport.
	glViewport(0, 0, Screen.w, Screen.h);

	//Reset the projection matrix.
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	AspectRoot := SqRt(Screen.w / Screen.h);
	iAspectRoot := 1 / AspectRoot;
	glFrustum(-NearClip/2 * AspectRoot, +NearClip/2 * AspectRoot, -NearClip/2 * iAspectRoot, +NearClip/2 * iAspectRoot, NearClip, FarClip);

	//Reset the modelview matrix.
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();

	//Enable texture mapping.
	glEnable(GL_TEXTURE_2D);

	//Enable polycoloring.
	glEnable(GL_COLOR_MATERIAL);
	glColorMaterial(GL_FRONT, GL_DIFFUSE);
	//glMaterialfv(GL_FRONT, GL_AMBIENT, InstantArrayPtr(0, 0, 0, 1));
	//glMaterialfv(GL_BACK, GL_AMBIENT_AND_DIFFUSE, InstantArrayPtr(1, 0, 0, 1));

	//Enable vertex shading.
	glShadeModel(GL_SMOOTH);

	//Leave alpha blending off, but configure ahead of time for the few alpha-blended textures.
	//glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	//Enable depth testing.
	glEnable(GL_DEPTH_TEST);
	glDepthFunc(GL_LEQUAL);

	//Set clear color to black.
	glClearColor(0, 0, 0, 0);
	//Set clear depth to max.
	glClearDepth(1.0);

	//Really nice perspective calculations.
	glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);

	//Enable lighting.
	glEnable(GL_LIGHTING);
	//glLightModelfv(GL_LIGHT_MODEL_AMBIENT, InstantArrayPtr(0.0, 0.0, 0.0, 1));
	glLightModelfv(GL_LIGHT_MODEL_AMBIENT, InstantArrayPtr(0.05, 0.025, 0.0, 1));

	glEnable(GL_LIGHT0);
	//glLightf(GL_LIGHT0, GL_LINEAR_ATTENUATION, 1);
	//glLightfv(GL_LIGHT0, GL_AMBIENT, InstantArrayPtr(0.125, 0.125, 0.125, 1));
	//glLightfv(GL_LIGHT0, GL_DIFFUSE, InstantArrayPtr(0.5, 0.5, 0.5, 1));
	//glLightfv(GL_LIGHT0, GL_SPECULAR, InstantArrayPtr(0.25, 0.25, 0.5, 1));

	glLightfv(GL_LIGHT0, GL_DIFFUSE, InstantArrayPtr(0.3, 0.35, 0.4, 1));

	{
	//Enable lighting.
	glEnable(GL_LIGHTING);
	//glLightf(GL_LIGHT0, GL_LINEAR_ATTENUATION, 0.1);
	glLightfv(GL_LIGHT0, GL_AMBIENT, InstantArrayPtr(0.1, 0.1, 0.1, 1));
	glLightfv(GL_LIGHT0, GL_DIFFUSE, InstantArrayPtr(1, 1, 1, 1));
	//glLightfv(GL_LIGHT0, GL_SPECULAR, InstantArrayPtr(0.25, 0.25, 0.5, 1));
	glEnable(GL_LIGHT0);
	//glLightModeli(GL_LIGHT_MODEL_TWO_SIDE, 1);
	}

	KeyData := TKeyData.Create;

	LoadTexFont(MyFont, 'Verdana.ccf');

	{
	InitGLibAperture;
	hStarImg := LoadRGBAPNG('Star.png');
	}
	GenProcTextures;
	SetBoundTexture(0);

	LoadBuildScript;
	//NewBuildings;
	SetLength(Neighborhood, 1);
	Neighborhood[0] := BuildNeighborhoodFromType(NeighborhoodType[0]);

	Player.Loc := Vector(0, 0.5, 13);
	Player.Facing.Z := -1;
	Camera.Loc := Player.Loc;
	Camera.Facing := Player.Facing;
	Player.Speed := 3;

	MouseSensitivity := 8000 / Screen.w;
	ExtractMousePos;
end;

procedure CleanupGame;
var
	I: Integer;

begin
	for I := 0 to High(Neighborhood) do FreeAndNil(Neighborhood[I]);
	SetLength(Neighborhood, 0);
	for I := 0 to High(NeighborhoodType) do FreeAndNil(NeighborhoodType[I]);
	SetLength(NeighborhoodType, 0);
	for I := 0 to High(Faction) do FreeAndNil(Faction[I]);
	SetLength(Faction, 0);
	for I := 0 to High(FactionType) do FreeAndNil(FactionType[I]);
	SetLength(FactionType, 0);

	FreeAndNil(KeyData);

	glDeleteTextures(1, @WindowedTex);
	glDeleteTextures(1, @RoofTex);
	glDeleteTextures(1, @ConcreteTex);
	glDeleteTextures(1, @SidewalkTex);
	glDeleteTextures(1, @AsphaltTex);
	glDeleteTextures(1, @BushyTex);
end;

procedure DoEvents;
var
	Event: TSDL_Event;

begin
	while SDL_PollEvent(@Event) <> 0 do case event.type_ of
		SDL_ACTIVEEVENT: begin
			if (event.active.state and SDL_APPINPUTFOCUS) <> 0 then bHasFocus := event.active.gain <> 0;
			if bHasFocus then ExtractMousePos;
		end;
		{
		SDL_ACTIVEEVENT: if ((event.active.state and SDL_APPINPUTFOCUS) <> 0) and Player.bWantMouselook and (event.active.gain <> Byte(Ord(Player.bMouselook))) then begin
			SDL_ShowCursor(Ord(Player.bMouselook));
			Player.bMouselook := not Player.bMouselook;
			if Player.bMouselook then SetCursorPos(Screen.w div 2, Screen.h div 2);
		end;
		}
		SDL_QUITEV: Done := True;
		SDL_KEYDOWN: begin
			if (event.key.keysym.sym = SDLK_Escape) and (KeyData.BuckyState = []) then Done := True;
			if (event.key.keysym.sym = SDLK_Return) and (KeyData.BuckyState = []) then NewBuildings();
			//if (event.key.keysym.sym = SDLK_S) and (KeyData.BuckyState = [bkCtrl]) then Player.DoSaveClick(event.key.keysym.sym);
			if event.key.keysym.sym < 512 then KeyData.KeyDown[event.key.keysym.sym] := True;
		end;
		SDL_KEYUP: if event.key.keysym.sym < 512 then KeyData.KeyDown[event.key.keysym.sym] := False;
		SDL_MOUSEBUTTONDOWN: if Event.button.button < SDLK_BACKSPACE then KeyData.KeyDown[Event.button.button] := True;
		SDL_MOUSEBUTTONUP  : if Event.button.button < SDLK_BACKSPACE then KeyData.KeyDown[Event.button.button] := False;
		//SDL_MOUSEMOTION: ;
	end;
end;

function DoTime: LongWord;
var
	ThisTime: LongWord;

begin
	repeat
		DoEvents;

		ThisTime := SDL_GetTicks();
		if ThisTime <> LastTime then Break;
		Sleep(0);
	until False;

	Result := ThisTime - LastTime;
	LastTime := ThisTime;
	if Result > 50 then Result := 50;
end;

procedure DoPhysics(dT: LongWord);
const
	VNZ: T3Vector = (X: 0; Y: 0; Z: -1);

var
	fdT: TReal;
	J, R, U: T3Vector;
	I: Integer;
	dMus: TPoint;

begin
	fdT := dT * 0.001;
	FrameRate := 1 / fdT;
	SmoothedFrameRate := SmoothedFrameRate * 0.9 + FrameRate * 0.1;
	if fdT > 0.1 then fdT := 0.1;

	Rot := Rot + fdT * 360/45;
	if Rot >= 360 then Rot := Rot - 360;

	if bHasFocus then begin
		//Change camera facing based on mouselook.
		dMus := ExtractMousePos;
		with Camera do begin
			MouseYaw := MouseYaw - dMus.X*MouseSensitivity*fdT;
			MousePitch := Min(80, Max(-80, MousePitch + dMus.Y*MouseSensitivity*fdT));
			Facing := VYaw(MouseYaw, VPitch(MousePitch, VNZ));
		end;
	end;
	R := VNormal(VCrossProd(Camera.Facing, VY));

	//Change player facing towards camera facing.
	U := VProd(Camera.Facing, 0.1);
	for I := 1 to dT do
		Player.Facing := VSum(VProd(Player.Facing, 0.9), U)
	;
	VNormalize(Player.Facing);

	//Player movement.
	J.X := Ord(KeyData[SDLK_Right] or KeyData[SDLK_KP_Right])
	     - Ord(KeyData[SDLK_Left] or KeyData[SDLK_KP_Left]);
	J.Y := Ord(KeyData[SDLK_KP_Plus])
	     - Ord(KeyData[SDLK_KP_Enter]);
	J.Z := Ord(KeyData[SDLK_Up] or KeyData[SDLK_KP_Up])
	     - Ord(KeyData[SDLK_Down] or KeyData[SDLK_KP_Down]);
	if J.X <> 0 then VADD(Player.Loc, VProd(R, Player.Speed * J.X * fdT));
	if J.Y <> 0 then VADD(Player.Loc, VProd(VY, Player.Speed * J.Y * fdT));
	if J.Z <> 0 then VADD(Player.Loc, VProd(Camera.Facing, Player.Speed * J.Z * fdT));
	KeyData.ClearPress;

	//Move camera to player.
	Camera.Loc := Player.Loc;

	//Build OpenGL matrix to represent camera facing.
	with Camera do begin
		U := VNormal(VCrossProd(R, Facing));
		FM[0] := R.X;
		FM[1] := U.X;
		FM[2] := -Facing.X;
		FM[3] := 0;
		FM[4] := R.Y;
		FM[5] := U.Y;
		FM[6] := -Facing.Y;
		FM[7] := 0;
		FM[8] := R.Z;
		FM[9] := U.Z;
		FM[10] := -Facing.Z;
		FM[11] := 0;
		FM[12] := 0;
		FM[13] := 0;
		FM[14] := 0;
		FM[15] := 1;
	end;
end;

function VAvg(const A, B: T3Vector): T3Vector;
begin
  Result.X := (A.X + B.X) * 0.5;
  Result.Y := (A.Y + B.Y) * 0.5;
  Result.Z := (A.Z + B.Z) * 0.5;
end;

procedure Triangle(const A, B, C: T3Vector);
begin
	with A do glVertex3f(X, Y, Z);
	with B do glVertex3f(X, Y, Z);
	with C do glVertex3f(X, Y, Z);
end;

procedure SubdividedTriangle(const A, B, C: T3Vector; Subdivision: LongWord);
var
	AB, BC, CA: T3Vector;

begin
	AB := VAvg(A, B);
	BC := VAvg(B, C);
	CA := VAvg(C, A);

	if Subdivision > 1 then begin
		Dec(Subdivision);
		SubdividedTriangle(AB, BC, CA, Subdivision);
		SubdividedTriangle(A, AB, CA, Subdivision);
		SubdividedTriangle(B, BC, AB, Subdivision);
		SubdividedTriangle(C, CA, BC, Subdivision);
	end
	else begin
		Triangle(AB, BC, CA);
		Triangle(A, AB, CA);
		Triangle(B, BC, AB);
		Triangle(C, CA, BC);
	end;
end;

procedure TriangleWithNormals(const A, B, C: T3Vector; Subdivision: LongWord = 0);
var
	xA, xB, N: T3Vector;

begin
	//Split triangle into two vectors, B and C from A
	xA := VDiff(B, A);
	xB := VDiff(C, A);
	//N = normal cross product of xA and xB
	N := VNormal(VCrossProd(xA, xB));

	with N do glNormal3f(X, Y, Z);
	if Subdivision = 0 then
		Triangle(A, B, C)
	else
		SubdividedTriangle(A, B, C, Subdivision)
	;
end;

procedure DrawTriforce(ES, EC: Extended);
begin
	glBegin(GL_TRIANGLES);
		TriangleWithNormals(Vector(0, 0, -0.2), Vector(ES, EC, 0), Vector(-ES, EC, 0));
		TriangleWithNormals(Vector(0, 1, 0), Vector(0, 0, -0.2), Vector(-ES, EC, 0));
		TriangleWithNormals(Vector(0, 1, 0), Vector(ES, EC, 0), Vector(0, 0, -0.2));

		TriangleWithNormals(Vector(0, 0, +0.2), Vector(ES, EC, 0), Vector(0, 1, 0));
		TriangleWithNormals(Vector(-ES, EC, 0), Vector(0, 0, +0.2), Vector(0, 1, 0));
		TriangleWithNormals(Vector(-ES, EC, 0), Vector(ES, EC, 0), Vector(0, 0, +0.2));
	glEnd;
end;

procedure PrintFPS(bX, bY, bZ, ThisRate: TReal);
var
	I: Integer;
	Buf: String;

begin
	Buf := IntToStr(Round(ThisRate)) + ' FPS';
	for I := 1 to Length(Buf) do begin
		SetBoundTexture(MyFont[Byte(Buf[I])]);
		glBegin(GL_QUADS);
			glTexCoord2i(0, 0); glVertex3f(bX + I - 1, bY + 1, bZ);
			glTexCoord2i(0, 1); glVertex3f(bX + I - 1, bY - 1, bZ);
			glTexCoord2i(1, 1); glVertex3f(bX + I + 1, bY - 1, bZ);
			glTexCoord2i(1, 0); glVertex3f(bX + I + 1, bY + 1, bZ);
		glEnd;
	end;
end;

procedure RenderNeighborhoodWithStyle(N: TNeighborhood; Style: TPolyStyles);
var
	iD, iX, iZ: Integer;

begin
	with N do begin
		{//The naive implementation, in case the optimization becomes a problem.
			for iX := Low(CityBlock) to High(CityBlock) do
				for iZ := Low(CityBlock[iX]) to High(CityBlock[iX]) do
					RenderBuildingWithStyle(CityBlock[iX, iZ].Building, Style)
			;
		}

		RenderBuildingWithStyle(CityBlock[0, 0].Building, Style);
		for iD := 1 to 20 do begin
			for iX := -iD to +iD do begin
				RenderBuildingWithStyle(CityBlock[iX, -iD].Building, Style);
				RenderBuildingWithStyle(CityBlock[iX, +iD].Building, Style);
			end;
			for iZ := -iD+1 to +iD-1 do begin
				RenderBuildingWithStyle(CityBlock[-iD, iZ].Building, Style);
				RenderBuildingWithStyle(CityBlock[+iD, iZ].Building, Style);
			end;
		end;
	end;
end;

procedure DoGraphics;
begin
	glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
	glLoadIdentity();

	glColor3f(1, 1, 1);
	glPushMatrix;
		glMultMatrixf(@Camera.FM[0]);
		//`@ Skybox...
		//glDisable(GL_DEPTH_TEST);
		//glEnable(GL_DEPTH_TEST);
		with Camera.Loc do glTranslatef(-X, -Y, -Z);
		glLightfv(GL_LIGHT0, GL_POSITION, InstantArrayPtr(-7, 13, 15, 0)); //Directional light.

		//`@ Eventually, we should split the polies by texture and style.
		//`@ And then sort the closest to the camera first.
		glDisable(GL_LIGHTING);
		RenderNeighborhoodWithStyle(Neighborhood[0], []);
		glEnable(GL_LIGHTING);
		RenderNeighborhoodWithStyle(Neighborhood[0], [psLit]);
		SetBoundTexture(AsphaltTex);
		//SetBoundTexture(ConcreteTex);
		glBegin(GL_QUADS);
			glNormal3f(0, 1, 0);
			glTexCoord2f(0, 1066);
			glVertex3f(-533, 0, 533);
			glTexCoord2f(1066, 1066);
			glVertex3f(533, 0, 533);
			glTexCoord2f(1066, 0);
			glVertex3f(533, 0, -533);
			glTexCoord2f(0, 0);
			glVertex3f(-533, 0, -533);
		glEnd;
	glPopMatrix;

	glDisable(GL_LIGHTING);
	glDisable(GL_DEPTH_TEST);
	glEnable(GL_BLEND);
	if FrameRate < 10 then
		glColor3f(1, 0, 0)
	else
		glColor3f(1, 1, 1)
	;
	PrintFPS(-15, +10, -30, FrameRate);
	if SmoothedFrameRate < 10 then
		glColor3f(1, 0, 0)
	else
		glColor3f(1, 1, 1)
	;
	PrintFPS(-15, +8, -30, SmoothedFrameRate);
	glDisable(GL_BLEND);
	glEnable(GL_DEPTH_TEST);
	glEnable(GL_LIGHTING);

	SDL_GL_SwapBuffers();
end;

end.
