unit DGTKControls;

interface

uses
	GLib2, GDK2, GTK2,
	DUtils, DGTKGraphics;

type
	TDNotifyEvent = procedure (Sender: TObject) of object;
	TDExposeEvent = procedure (Sender: TObject; Event: PGDKEventExpose) of object;

type
	TDMenuItem = class;
	TDSubMenu = class;
	TDMenuEvent = class;
	TDMenuSepBar = class;

	TDMenuBar = class
	public
		GTKOb: PGTKMenuBar;

		constructor Create; virtual;

		function AddMenu(Title: String): TDSubMenu; virtual;
		procedure PackToVBox(VBox: pGTKVBox); virtual;
	end;

	TDMenuItem = class
	public
		GTKOb: PGTKMenuItem;

		constructor Create(Title: String); virtual;
	end;

	TDSubMenu = class(TDMenuItem)
	public
		SubmenuOb: PGTKMenu;

		constructor Create(Title: String); override;

		function AddSubMenu(Title: String): TDSubMenu; virtual;
		function AddMenuEvent(Title: String): TDMenuEvent; overload; virtual;
		function AddMenuEvent(Title: String; ActivateHandler: TDNotifyEvent): TDMenuEvent; overload; virtual;
		function AddSepBar: TDMenuSepBar; virtual;
	end;

	TDMenuEvent = class(TDMenuItem)
	public
		OnActivate: TDNotifyEvent;

		constructor Create(Title: String); overload; override;
		constructor Create(Title: String; ActivateHandler: TDNotifyEvent); overload; virtual;

		procedure Activate; virtual;
	end;

	TDMenuSepBar = class
	public
		GTKOb: PGTKSeparatorMenuItem;

		constructor Create; virtual;
	end;

	TDDrawingArea = class
	public
		GTKOb: PGTKDrawingArea;
		Canvas: TCanvas;

		OnPaint: TDExposeEvent;

		constructor Create; virtual;
		destructor Destroy; override;

		procedure NeedsCanvas; virtual;
		procedure QueueDraw; virtual;
	end;

	TDButton = class
	public
		GTKOb: PGTKButton;

		OnClicked: TDNotifyEvent;

		constructor Create; overload;

		FTitle: String;
		procedure SetTitle(NewTitle: String); virtual;
		property Title: String read FTitle write SetTitle;
	end;

	TPackStyle = (psFixed, psExpand, psPad);

function TextViewToStr(TextView: PGTKTextView): String;





implementation

uses
	SysUtils;

function TextViewToStr(TextView: PGTKTextView): String;
var
	ThisBuffer: pGTKTextBuffer;
	StartIter, EndIter: TGTKTextIter;

begin
	ThisBuffer := GTK_Text_View_Get_Buffer(TextView);
	GTK_Text_Buffer_Get_Bounds(ThisBuffer, @StartIter, @EndIter);
	Result := GTK_Text_Buffer_Get_Text(ThisBuffer, @StartIter, @EndIter, False);
end;

{ TDMenuBar }

constructor TDMenuBar.Create;
begin
	GTKOb := PGTKMenuBar(GTK_Menu_Bar_New);
end;

function TDMenuBar.AddMenu(Title: String): TDSubMenu;
begin
	Result := TDSubMenu.Create(Title);
	GTK_Menu_Bar_Append(PGTKWidget(GTKOb), PGTKWidget(Result.GTKOb));
end;

procedure TDMenuBar.PackToVBox(VBox: pGTKVBox);
begin
	GTK_Box_Pack_Start(pGTKBox(VBox), pGTKWidget(GTKOb), False, False, 0);
end;

{ TDMenuItem }

constructor TDMenuItem.Create(Title: String);
begin
	GTKOb := PGTKMenuItem(GTK_Menu_Item_New_With_Mnemonic(PChar(Title)));
	Title := '';
end;

{ TDSubMenu }

constructor TDSubMenu.Create(Title: String);
begin
	inherited;

	SubmenuOb := PGTKMenu(GTK_Menu_New);
	GTK_Menu_Item_Set_Submenu(GTK_MENU_ITEM(GTKOb), PGTKWidget(SubmenuOb));
end;

function TDSubMenu.AddSubMenu(Title: String): TDSubMenu;
begin
	Result := TDSubMenu.Create(Title);
	GTK_Menu_Shell_Append(GTK_MENU_SHELL(SubmenuOb), PGTKWidget(Result.GTKOb));
end;

function TDSubMenu.AddMenuEvent(Title: String): TDMenuEvent;
begin
	Result := TDMenuEvent.Create(Title);
	GTK_Menu_Shell_Append(GTK_MENU_SHELL(SubmenuOb), PGTKWidget(Result.GTKOb));
end;

function TDSubMenu.AddMenuEvent(Title: String; ActivateHandler: TDNotifyEvent): TDMenuEvent;
begin
	Result := TDMenuEvent.Create(Title, ActivateHandler);
	GTK_Menu_Shell_Append(GTK_MENU_SHELL(SubmenuOb), PGTKWidget(Result.GTKOb));
end;

function TDSubMenu.AddSepBar: TDMenuSepBar;
begin
	Result := TDMenuSepBar.Create;
	GTK_Menu_Shell_Append(GTK_MENU_SHELL(SubmenuOb), PGTKWidget(Result.GTKOb));
end;

{ TDMenuEvent }

procedure OnMenuEventActivate(Widget: PGTKWidget; Sender: TDMenuEvent); cdecl;
begin
	Sender.Activate;
end;

constructor TDMenuEvent.Create(Title: String);
begin
	inherited;

	G_Signal_Connect(G_OBJECT(GTKOb), 'activate', GTK_SIGNAL_FUNC(@OnMenuEventActivate), Self);
end;

constructor TDMenuEvent.Create(Title: String; ActivateHandler: TDNotifyEvent);
begin
	Create(Title);
	OnActivate := ActivateHandler;
end;

procedure TDMenuEvent.Activate;
var
	ThisOnActivate: TDNotifyEvent;

begin
	ThisOnActivate := OnActivate;
	if Assigned(ThisOnActivate) then
		ThisOnActivate(Self)
	;
end;

{ TDMenuSepBar }

constructor TDMenuSepBar.Create;
begin
	GTKOb := PGTKSeparatorMenuItem(GTK_Separator_Menu_Item_New);
end;

{ TDDrawingArea }

function OnDrawingAreaExpose(Widget: PGTKWidget; Event: PGDKEventExpose; Area: TDDrawingArea): LongBool; cdecl;
begin
	Result := True;

	if Assigned(Area.OnPaint) then
		Area.OnPaint(Area, Event)
	;
end;

constructor TDDrawingArea.Create;
begin
	GTKOb := PGTKDrawingArea(GTK_Drawing_Area_New);

	G_Signal_Connect(GTKOb, 'expose_event', G_CALLBACK(@OnDrawingAreaExpose), Self);
end;

destructor TDDrawingArea.Destroy;
begin
	FreeAndNil(Canvas);

	inherited;
end;

procedure TDDrawingArea.NeedsCanvas;
begin
	if Canvas = nil then Canvas := TCanvas.Create(PGTKWidget(GTKOb).Window);
end;

procedure TDDrawingArea.QueueDraw;
begin
	GTK_Widget_Queue_Draw(PGTKWidget(GTKOb));
end;

{ TDButton }

procedure OnButtonClicked(Widget: PGTKWidget; Sender: TDButton); cdecl;
var
	F: TDNotifyEvent;

begin
	F := Sender.OnClicked;
	if Assigned(F) then
		F(Sender)
	;
end;

constructor TDButton.Create;
begin
	GTKOb := PGTKButton(GTK_Button_New);
	G_Signal_Connect(GTKOb, 'clicked', TGCallback(@OnButtonClicked), Self);
	GTK_Button_Set_Use_Underline(GTKOb, True);
end;

procedure TDButton.SetTitle(NewTitle: String);
begin
	GTK_Button_Set_Label(GTKOb, PChar(NewTitle));
	FTitle := NewTitle;
end;

end.
