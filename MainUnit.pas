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
	GL, GLD, GLPNG,
	DUtils, D3Vectors,
	SpaceTextures,
	Buildings;

type
	TFColor = record
		R, G, B: TReal;
	end;

	TPlayerData = record
		Loc: T3Vector;
		Rot, TarRot: TReal;
	end;

var
	Rot: TReal;
	hStarImg: LongWord;
	Player: TPlayerData;
	FrameRate, SmoothedFrameRate: TReal;
	Buildings: array [0..8] of TBuildingData;


procedure FirstInit;
begin
end;

function GetSDLFlags: LongWord;
begin
	Result := SDL_INIT_VIDEO;
	//Flags := Flags or SDL_INIT_AUDIO;
end;

procedure NewBuildings;
var
	Building: TBuildingData;
begin
	Building := GenericBuilding();
	OffsetBuilding(Building, Vector(-25,0,-25));
	Buildings[0] := Building;

	Building := GenericBuilding();
	OffsetBuilding(Building, Vector(-25,0,0));
	Buildings[1] := Building;

	Building := GenericBuilding();
	OffsetBuilding(Building, Vector(-25,0,25));
	Buildings[2] := Building;

	Building := GenericBuilding();
	OffsetBuilding(Building, Vector(0,0,-25));
	Buildings[3] := Building;

	Buildings[4] := CubistTumorBuilding();

	Building := GenericBuilding();
	OffsetBuilding(Building, Vector(0,0,25));
	Buildings[5] := Building;

	Building := GenericBuilding();
	OffsetBuilding(Building, Vector(25,0,-25));
	Buildings[6] := Building;

	Building := GenericBuilding();
	OffsetBuilding(Building, Vector(25,0,0));
	Buildings[7] := Building;

	Building := GenericBuilding();
	OffsetBuilding(Building, Vector(25,0,25));
	Buildings[8] := Building;
end;

procedure InitGame;
const
	NearClip = 1.0;
	FarClip = NearClip * 1000;

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
	glLightModelfv(GL_LIGHT_MODEL_AMBIENT, InstantArrayPtr(0.0, 0.0, 0.0, 1));

	glEnable(GL_LIGHT0);
	//glLightf(GL_LIGHT0, GL_LINEAR_ATTENUATION, 1);
	//glLightfv(GL_LIGHT0, GL_AMBIENT, InstantArrayPtr(0.125, 0.125, 0.125, 1));
	//glLightfv(GL_LIGHT0, GL_DIFFUSE, InstantArrayPtr(0.5, 0.5, 0.5, 1));
	//glLightfv(GL_LIGHT0, GL_SPECULAR, InstantArrayPtr(0.25, 0.25, 0.5, 1));

	glLightfv(GL_LIGHT0, GL_POSITION, InstantArrayPtr(-7, 13, 15, 1));

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

	LoadTexFont(MyFont, 'Verdana.ccf');

	{InitGLibAperture;
	hStarImg := LoadRGBAPNG('Star.png');}
	SetBoundTexture(0);

	KeyData := TKeyData.Create;
	NewBuildings();
end;

procedure CleanupGame;
begin
	FreeAndNil(KeyData);
end;

procedure DoEvents;
var
	Event: TSDL_Event;

begin
	while SDL_PollEvent(@Event) <> 0 do case event.type_ of
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
			if event.key.keysym.sym < 512 then KeyData[event.key.keysym.sym] := True;
		end;
		SDL_KEYUP: if event.key.keysym.sym < 512 then KeyData[event.key.keysym.sym] := False;
		SDL_MOUSEBUTTONDOWN: if Event.button.button < SDLK_BACKSPACE then KeyData[Event.button.button] := True;
		SDL_MOUSEBUTTONUP  : if Event.button.button < SDLK_BACKSPACE then KeyData[Event.button.button] := False;
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
var
	fdT: TReal;
	ES, EC: Extended;

begin
	fdT := dT * 0.001;
	FrameRate := 1 / fdT;
	SmoothedFrameRate := SmoothedFrameRate * 0.9 + FrameRate * 0.1;

	Rot := Rot + fdT * 360/2;
	if Rot >= 360 then Rot := Rot - 360;
	Player.Rot := Player.Rot + fdT * 0.3;
	if Player.Rot >= FullCircle then Player.Rot := Player.Rot - FullCircle;
	ES := 0;
	EC := 0;
	SinCos(Player.Rot, ES, EC);
	with Player.Loc do begin
		X := X + ES * fdT;
		Y := Y - EC * fdT;
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

procedure DoGraphics;
const
	StarPlanes = 4;
	SPF = 1 / (StarPlanes + 0.5);

var
	ES, EC: Extended;
	Z, dX, dY: TReal;
	I: Integer;

begin
	glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
	glLoadIdentity();

	{glDisable(GL_LIGHTING);
	glDisable(GL_DEPTH_TEST);
	glEnable(GL_BLEND);
	SetBoundTexture(hStarImg);
	glColor3f(1, 1, 1);
	SinCos(Player.Rot, ES, EC);
	glBegin(GL_QUADS);
		with Player.Loc do begin
			dX := X - Floor(X);
			dY := Y - Floor(Y);
		end;
		for I := 1 to StarPlanes do begin
			Z := SqRt(1 - I * SPF) * 14;
			glTexCoord2f(dX + 0, dY + 0); glVertex3f(-EC -ES, +EC -ES, -1);
			glTexCoord2f(dX + 0, dY + Z); glVertex3f(-EC +ES, -EC -ES, -1);
			glTexCoord2f(dX + Z, dY + Z); glVertex3f(+EC +ES, -EC +ES, -1);
			glTexCoord2f(dX + Z, dY + 0); glVertex3f(+EC -ES, +EC +ES, -1);
		end;
	glEnd;
	SetBoundTexture(0);
	glDisable(GL_BLEND);
	glEnable(GL_DEPTH_TEST);
	glEnable(GL_LIGHTING);}

	glColor3f(1, 1, 0);
	glMaterialfv(GL_FRONT, GL_SPECULAR, InstantArrayPtr(1, 1, 1, 0));
	glMaterialfv(GL_FRONT, GL_SHININESS, InstantArrayPtr(32));
	SinCos(FullCircle / 3, ES, EC);
	{glPushMatrix;
		glTranslatef(0, 1, -10);
		gldYaw(Rot);
		DrawTriforce(ES, EC);
	glPopMatrix;
	glPushMatrix;
		glTranslatef(ES, EC, -10);
		gldYaw(Rot);
		DrawTriforce(ES, EC);
	glPopMatrix;
	glPushMatrix;
		glTranslatef(-ES, EC, -10);
		gldYaw(Rot);
		DrawTriforce(ES, EC);
	glPopMatrix;}
	
	glPushMatrix;
		glTranslatef(0, -25, -200);
		gldYaw(Rot);
		for I := 0 to length(Buildings) do begin
			RenderBuilding(Buildings[I]);
		end;
	glPopMatrix;

	glDisable(GL_LIGHTING);
	glDisable(GL_DEPTH_TEST);
	glEnable(GL_BLEND);
	glColor3f(1, 1, 1);
	PrintFPS(-15, +10, -30, FrameRate);
	PrintFPS(-15, +8, -30, SmoothedFrameRate);
	glDisable(GL_BLEND);
	glEnable(GL_DEPTH_TEST);
	glEnable(GL_LIGHTING);

	SDL_GL_SwapBuffers();
end;
end.
