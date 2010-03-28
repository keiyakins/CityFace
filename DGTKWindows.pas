unit DGTKWindows;

interface

uses
	GLib2, GDK2, GTK2,
	DUtils, DGTKControls;

type
	TDWindow = class
	public
		constructor Create; virtual;
		destructor Destroy; override;
		Window: PGTKWindow;
		AccelGroup: PGTKAccelGroup;

		FTitle: String;
		procedure SetTitle(NewTitle: String); virtual;
		property Title: String read FTitle write SetTitle;
		WindowState: TGDKWindowState;

		procedure EnableDropFiles(NewState: Boolean = True); virtual;
		procedure HandleDropFiles(Paths: TStringArray); virtual;

		procedure MakeAccelGroup; virtual;
		procedure AddWidgetAccel(Widget: PGTKWidget; AccelKey: LongWord; AccelModifiers: TGDKModifierType; Flags: TGTKAccelFlags = GTK_ACCEL_VISIBLE); virtual;
		procedure AddMenuItemAccel(MenuItem: TDMenuItem; AccelKey: LongWord; AccelModifiers: TGDKModifierType; Flags: TGTKAccelFlags = GTK_ACCEL_VISIBLE); virtual;
	end;
	TDWindowClass = class of TDWindow;

	TButtonResponse = record
		Caption: String;
		Response: Integer;
	end;

	TDApplication = class
	public
		MainWindow: TDWindow;
		bShowMainWindow: Boolean;
		constructor Create; virtual;
		procedure Initialize; virtual;
		procedure Run; virtual;
		procedure AddDialogButtons(Dialog: PGTKDialog; const Buttons: array of TButtonResponse; DefaultIndex, CancelIndex: Integer);
		function ModalEntryDialog(Parent: PGTKWindow; Prompt: String; var Text: String; OKCaption, CancelCaption: String): Boolean;
		function ModalMessageDialog(Parent: PGTKWindow; MessageType: TGTKMessageType; MessageText: String; const Buttons: array of TButtonResponse; DefaultIndex: Integer = -1; CancelIndex: Integer = -1): Integer;
		function ModalMessageOKDialog(Parent: PGTKWindow; MessageType: TGTKMessageType; MessageText: String): Integer;
		procedure ProcessMessages;
	end;

var
  App: TDApplication;





implementation

uses
	SysUtils,
	DGUtils;

{ TDWindow }

procedure DestroyWindow(Widget: PGTKWidget; Window: TDWindow); cdecl;
begin
	Window.Free;
end;

function OnWindowStateEvent(Widget: PGTKWidget; State: PGDKEventWindowState; Window: TDWindow): LongBool; cdecl;
begin
	Result := False;

	Window.WindowState := State.New_Window_State;
end;

procedure OnReceiveDrag(Widget: PGTKWidget; DragContext: PGDKDragContext; X, Y: LongInt; SelData: PGTKSelectionData; Info, Time: LongWord; Window: TDWindow); cdecl;
var
	ListStr: String;
	FNs: TStringArray;
	I: Integer;

begin
	if (SelData.Length >= 0) and (SelData.Format = 8) then begin
		SetString(ListStr, PChar(SelData.Data), SelData.Length);
		ListStr := Trim(ListStr);
		ListStr := StringReplace(ListStr, #13#10, #13, [rfReplaceAll]);
		ListStr := StringReplaceC(ListStr, #10, #13);
		FNs := StrTokenize(ListStr, #13);
		for I := 0 to High(FNs) do
			FNs[I] := GStrToStr(G_Filename_From_URI(PChar(FNs[I]), nil, nil))
		;
		Window.HandleDropFiles(FNs);

		GTK_Drag_Finish(DragContext, True, False, Time);
	end
	else begin
		GTK_Drag_Finish(DragContext, False, False, Time);
	end;
end;

constructor TDWindow.Create;
begin
	Window := pGTKWindow(GTK_Window_New(GTK_WINDOW_TOPLEVEL));
	G_Signal_Connect(PGTKObject(Window), 'destroy', GTK_SIGNAL_FUNC(@DestroyWindow), Self);
	G_Signal_Connect(PGTKObject(Window), 'window-state-event', GTK_SIGNAL_FUNC(@OnWindowStateEvent), Self);
	if App.MainWindow = nil then App.MainWindow := Self;
end;

destructor TDWindow.Destroy;
begin
	if Self = App.MainWindow then begin
		App.MainWindow := nil;
		GTK_Main_Quit;
	end;

	inherited;
end;

procedure TDWindow.SetTitle(NewTitle: String);
begin
	if NewTitle <> FTitle then begin
		GTK_Window_Set_Title(Window, PChar(NewTitle));
		FTitle := NewTitle;
	end;
end;

procedure TDWindow.EnableDropFiles(NewState: Boolean = True);
var
	TargetEntry: TGTKTargetEntry;
	TargetStr: String;

begin
	TargetStr := 'text/uri-list';
	TargetEntry.Target := PChar(TargetStr);
	TargetEntry.Flags := 0;
	TargetEntry.Info := 0;
	GTK_Drag_Dest_Set(PGTKWidget(Window), GTK_DEST_DEFAULT_ALL, @TargetEntry, 1, GDK_ACTION_COPY);
	TargetStr := '';
	G_Signal_Connect(Window, 'drag-data-received', @OnReceiveDrag, Self);
end;

procedure TDWindow.HandleDropFiles(Paths: TStringArray);
begin end;

procedure TDWindow.MakeAccelGroup;
begin
	AccelGroup := PGTKAccelGroup(GTK_Accel_Group_New);
	GTK_Window_Add_Accel_Group(Window, AccelGroup);
end;

procedure TDWindow.AddWidgetAccel(Widget: PGTKWidget; AccelKey: LongWord; AccelModifiers: TGDKModifierType; Flags: TGTKAccelFlags = GTK_ACCEL_VISIBLE);
begin
	GTK_Widget_Add_Accelerator(Widget, 'activate', AccelGroup, AccelKey, AccelModifiers, Flags);
end;

procedure TDWindow.AddMenuItemAccel(MenuItem: TDMenuItem; AccelKey: LongWord; AccelModifiers: TGDKModifierType; Flags: TGTKAccelFlags = GTK_ACCEL_VISIBLE);
begin
	AddWidgetAccel(PGTKWidget(MenuItem.GTKOb), AccelKey, AccelModifiers);
end;

{ TDApplication }

constructor TDApplication.Create;
begin
	bShowMainWindow := True;
end;

procedure TDApplication.Initialize;
begin
	// Initialize the GTK+ libraries.
	GTK_Init(@ArgC, @ArgV);
end;

procedure TDApplication.AddDialogButtons(Dialog: PGTKDialog; const Buttons: array of TButtonResponse; DefaultIndex, CancelIndex: Integer);
var
	I: Integer;
	Buf: String;
	ThisButton: PGTKWidget;

begin
	for I := 0 to High(Buttons) do begin
		Buf := Buttons[I].Caption;
		ThisButton := GTK_Dialog_Add_Button(Dialog, PChar(Buf), Buttons[I].Response);
		Buf := '';
		if I = DefaultIndex then begin
			GTK_Widget_Set_Flags(ThisButton, GTK_CAN_DEFAULT);
			GTK_Widget_Grab_Default(ThisButton);
		end;
		if I = CancelIndex then
			//`@
		;
	end;
end;

function TDApplication.ModalEntryDialog(Parent: PGTKWindow; Prompt: String; var Text: String; OKCaption, CancelCaption: String): Boolean;
var
	ThisDialog: PGTKDialog;
	ThisEntry: PGTKEntry;
	Buttons: array[0..1] of TButtonResponse;

begin
	Result := False;
	ThisDialog := PGTKDialog(GTK_Dialog_New);
	if ThisDialog = nil then Exit;

	GTK_Window_Set_Title(PGTKWindow(ThisDialog), PChar(Prompt));
	Prompt := '';

	GTK_Window_Set_Transient_For(PGTKWindow(ThisDialog), Parent);
	GTK_Window_Set_Destroy_With_Parent(PGTKWindow(ThisDialog), True);

	ThisEntry := PGTKEntry(GTK_Entry_New);
	GTK_Entry_Set_Text(ThisEntry, PChar(Text));
	Text := '';
	GTK_Box_Pack_Start(PGTKBox(ThisDialog.VBox), PGTKWidget(ThisEntry), False, True, 0);

	Buttons[0].Caption := OKCaption;
	Buttons[0].Response := GTK_RESPONSE_OK;
	Buttons[1].Caption := CancelCaption;
	Buttons[1].Response := GTK_RESPONSE_CANCEL;
	AddDialogButtons(ThisDialog, Buttons, 0, 1);

	Result := GTK_Dialog_Run(ThisDialog) = GTK_RESPONSE_OK;
	Text := GTK_Entry_Get_Text(ThisEntry);

	GTK_Widget_Destroy(PGTKWidget(ThisEntry));
	GTK_Widget_Destroy(PGTKWidget(ThisDialog));
end;

function TDApplication.ModalMessageDialog(Parent: PGTKWindow; MessageType: TGTKMessageType; MessageText: String; const Buttons: array of TButtonResponse; DefaultIndex: Integer = -1; CancelIndex: Integer = -1): Integer;
var
	ThisDialog: PGTKMessageDialog;

begin
	Result := GTK_RESPONSE_REJECT;
	if Length(Buttons) = 0 then Exit;

	ThisDialog := PGTKMessageDialog(GTK_Message_Dialog_New(
		Parent,
		GTK_DIALOG_DESTROY_WITH_PARENT,
		MessageType,
		GTK_BUTTONS_NONE,
		PChar(MessageText)
	));
	MessageText := '';
	if ThisDialog = nil then Exit;

	AddDialogButtons(PGTKDialog(ThisDialog), Buttons, DefaultIndex, CancelIndex);

	Result := GTK_Dialog_Run(PGTKDialog(ThisDialog));
	GTK_Widget_Destroy(PGTKWidget(ThisDialog));
end;

function TDApplication.ModalMessageOKDialog(Parent: PGTKWindow; MessageType: TGTKMessageType; MessageText: String): Integer;
var
	Buttons: array[0..0] of TButtonResponse;

begin
	Buttons[0].Caption := '_OK';
	Buttons[0].Response := GTK_RESPONSE_OK;
	Result := ModalMessageDialog(Parent, MessageType, MessageText, Buttons, 0, 0);
end;

procedure TDApplication.ProcessMessages;
begin
	Sleep(0);
	while GTK_Events_Pending <> 0 do
		GTK_Main_Iteration
	;
end;

procedure TDApplication.Run;
begin
	if bShowMainWindow then
		GTK_Widget_Show_All(pGTKWidget(App.MainWindow.Window))
	;

	// Start handling signals.
	GTK_Main();
end;





initialization
	App := TDApplication.Create;

finalization
	App.Free;

end.
