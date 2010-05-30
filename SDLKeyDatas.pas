unit SDLKeyDatas;

interface

uses
	SDL;

type
	TSDLKeyEvent = procedure (Key: TSDLKey) of object;
	TBuckyKey = (bkShift, bkCtrl, bkAlt);
	TBuckyState = set of TBuckyKey;

	TKeyData = class
	protected
		FKeyDown: array[0..511] of Boolean;
		FKeyPress: array[0..511] of Boolean;
		FOnKeyDown: array[0..511] of TSDLKeyEvent;
		FOnKeyUp: array[0..511] of TSDLKeyEvent;

		function GetKeyDown(Index: Integer): Boolean; virtual;
		procedure SetKeyDown(Index: Integer; const Value: Boolean); virtual;
		function GetKeyPress(Index: Integer): Boolean; virtual;
		function GetOnKeyDown(Index: Integer): TSDLKeyEvent; virtual;
		procedure SetOnKeyDown(Index: Integer; const Value: TSDLKeyEvent); virtual;
		function GetOnKeyUp(Index: Integer): TSDLKeyEvent; virtual;
		procedure SetOnKeyUp(Index: Integer; const Value: TSDLKeyEvent); virtual;
		function GetBuckyState: TBuckyState; virtual;
		function GetKeyDownPress(Index: Integer): Boolean; virtual;
	public
		property KeyDown[Index: Integer]: Boolean read GetKeyDown write SetKeyDown;
		property KeyDownPress[Index: Integer]: Boolean read GetKeyDownPress; default;
		property KeyPress[Index: Integer]: Boolean read GetKeyPress;
		property OnKeyDown[Index: Integer]: TSDLKeyEvent read GetOnKeyDown write SetOnKeyDown;
		property OnKeyUp[Index: Integer]: TSDLKeyEvent read GetOnKeyUp write SetOnKeyUp;
		property BuckyState: TBuckyState read GetBuckyState;
		procedure ClearPress; virtual;
	end;

const
	SDLK_KP_Up = SDLK_KP8;
	SDLK_KP_Down = SDLK_KP2;
	SDLK_KP_Left = SDLK_KP4;
	SDLK_KP_Right = SDLK_KP6;
	SDLK_KP_Home = SDLK_KP7;
	SDLK_KP_End = SDLK_KP1;
	SDLK_KP_PgUp = SDLK_KP9;
	SDLK_KP_PgDn = SDLK_KP3;



implementation

uses
	SysUtils, Classes;

{ TKeyData }

procedure TKeyData.ClearPress;
var
	I: Integer;

begin
	for I := 0 to High(FKeyPress) do FKeyPress[I] := False;
end;

function TKeyData.GetBuckyState: TBuckyState;
begin
	Result := [];
	if FKeyDown[SDLK_LSHIFT] or FKeyDown[SDLK_RSHIFT] then Include(Result, bkShift);
	if FKeyDown[SDLK_LCTRL ] or FKeyDown[SDLK_RCTRL ] then Include(Result, bkCtrl );
	if FKeyDown[SDLK_LALT  ] or FKeyDown[SDLK_RALT  ] then Include(Result, bkAlt  );
end;

function TKeyData.GetKeyDown(Index: Integer): Boolean;
begin
	if Index < 0 then raise EListError.Create('Key index ' + IntToStr(Index) + ' is impossibly low.');
	if Index > High(FKeyDown) then raise EListError.Create('Key index ' + IntToStr(Index) + ' is too high.');
	Result := FKeyDown[Index];
end;

function TKeyData.GetKeyDownPress(Index: Integer): Boolean;
begin
	if Index < 0 then raise EListError.Create('Key index ' + IntToStr(Index) + ' is impossibly low.');
	if Index > High(FKeyPress) then raise EListError.Create('Key index ' + IntToStr(Index) + ' is too high.');
	Result := FKeyDown[Index] or FKeyPress[Index];
end;

function TKeyData.GetKeyPress(Index: Integer): Boolean;
begin
	if Index < 0 then raise EListError.Create('Key index ' + IntToStr(Index) + ' is impossibly low.');
	if Index > High(FKeyPress) then raise EListError.Create('Key index ' + IntToStr(Index) + ' is too high.');
	Result := FKeyPress[Index];
end;

function TKeyData.GetOnKeyDown(Index: Integer): TSDLKeyEvent;
begin
	if Index < 0 then raise EListError.Create('Key index ' + IntToStr(Index) + ' is impossibly low.');
	if Index > High(FKeyDown) then raise EListError.Create('Key index ' + IntToStr(Index) + ' is too high.');
	Result := FOnKeyDown[Index];
end;

function TKeyData.GetOnKeyUp(Index: Integer): TSDLKeyEvent;
begin
	if Index < 0 then raise EListError.Create('Key index ' + IntToStr(Index) + ' is impossibly low.');
	if Index > High(FKeyDown) then raise EListError.Create('Key index ' + IntToStr(Index) + ' is too high.');
	Result := FOnKeyUp[Index];
end;

procedure TKeyData.SetKeyDown(Index: Integer; const Value: Boolean);
begin
	if Index < 0 then raise EListError.Create('Key index ' + IntToStr(Index) + ' is impossibly low.');
	if Index > High(FKeyDown) then raise EListError.Create('Key index ' + IntToStr(Index) + ' is too high.');
	if Value = FKeyDown[Index] then Exit;

	FKeyDown[Index] := Value;
	if Value then begin
		FKeyPress[Index] := True;

		if Assigned(FOnKeyDown[Index]) then FOnKeyDown[Index](Index);
	end
	else begin
		if Assigned(FOnKeyUp[Index]) then FOnKeyUp[Index](Index);
	end;
end;

procedure TKeyData.SetOnKeyDown(Index: Integer; const Value: TSDLKeyEvent);
begin
	if Index < 0 then raise EListError.Create('Key index ' + IntToStr(Index) + ' is impossibly low.');
	if Index > High(FKeyDown) then raise EListError.Create('Key index ' + IntToStr(Index) + ' is too high.');
	FOnKeyDown[Index] := Value;
end;

procedure TKeyData.SetOnKeyUp(Index: Integer; const Value: TSDLKeyEvent);
begin
	if Index < 0 then raise EListError.Create('Key index ' + IntToStr(Index) + ' is impossibly low.');
	if Index > High(FKeyDown) then raise EListError.Create('Key index ' + IntToStr(Index) + ' is too high.');
	FOnKeyUp[Index] := Value;
end;

end.
