unit main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.Menus,
  Registry, IniFiles, TlHelp32,
  OTLParallel, OTLTaskControl, taskbar, madExceptVcl, UCL.TUCaptionBar,
  UCL.TUThemeManager, UCL.TUForm, UCL.TUButton, UCL.TUSymbolButton, UCL.TUPanel,
  UCL.IntAnimation, UCL.TUScrollBox, UCL.TUContextMenu;

type
  TForm1 = class(TUForm)
    TrayIcon1: TTrayIcon;
    PopupMenu1: TPopupMenu;
    mnuPinnedIcons: TMenuItem;
    N1: TMenuItem;
    Exit1: TMenuItem;
    tmrUpdateTBinfo: TTimer;
    tmrOptions: TTimer;
    tmrThreadWaiter: TTimer;
    tmrCenter: TTimer;
    mnuStart: TMenuItem;
    mnuTray: TMenuItem;
    mnuFull: TMenuItem;
    mnuCenter: TMenuItem;
    mnuTransparent: TMenuItem;
    N2: TMenuItem;
    mnuAbout: TMenuItem;
    N3: TMenuItem;
    mnuStartwithWindows: TMenuItem;
    MadExceptionHandler1: TMadExceptionHandler;
    UCaptionBar1: TUCaptionBar;
    UThemeManager1: TUThemeManager;
    UButton1: TUButton;
    UButton2: TUButton;
    UButton3: TUButton;
    UButton4: TUButton;
    UPanel1: TUPanel;
    USymbolButton1: TUSymbolButton;
    UScrollBox1: TUScrollBox;
    UContextMenu1: TUContextMenu;
    About1: TMenuItem;
    N4: TMenuItem;
    Exit2: TMenuItem;
    USymbolButton2: TUSymbolButton;
    mnuCenterRelative: TMenuItem;
    procedure mnuPinnedIconsClick(Sender: TObject);
    procedure Exit1Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tmrUpdateTBinfoTimer(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure tmrThreadWaiterTimer(Sender: TObject);
    procedure tmrCenterTimer(Sender: TObject);
    procedure tmrOptionsTimer(Sender: TObject);
    procedure mnuStartClick(Sender: TObject);
    procedure mnuTrayClick(Sender: TObject);
    procedure mnuFullClick(Sender: TObject);
    procedure mnuCenterClick(Sender: TObject);
    procedure mnuTransparentClick(Sender: TObject);
    procedure mnuAboutClick(Sender: TObject);
    procedure mnuStartwithWindowsClick(Sender: TObject);
    procedure TrayIcon1DblClick(Sender: TObject);
    procedure UButton1Click(Sender: TObject);
    procedure USymbolButton1Click(Sender: TObject);
    procedure Exit2Click(Sender: TObject);
    procedure mnuCenterRelativeClick(Sender: TObject);
  private
    { Private declarations }
    Taskbar: TTaskbar;
    Taskbar2: TTaskbar;

    function FindWindowRecursive(hParent: HWND; szClass: PWideChar; szCaption:PWideChar): HWND;
    procedure GetTaskbarWindows;
    procedure Init;
    procedure AutoStartState;
    procedure SetAutoStart(runwithwindows: Boolean = True);
    procedure LoadINI;
    procedure SaveINI;
    function InjectDLL(const dwPID: DWORD; DLLPATH: PChar): Integer;
    function GetProcessIdByName(s: String): DWORD;
  public
    { Public declarations }
  protected
    procedure WndProc(var Msg: TMessage); override;
  end;

  //Requires setversion.cmd to be run prior to build for release
  {$include RELEASENUMBER.inc}
  {$include VERSION.inc}

var
  Form1: TForm1;
  // Global variables
  AppIsRunning: Boolean = False;
  ThreadIsRunning: Boolean = False;
  CloseApp: Boolean = False;
  fwm_TaskbarRestart: Cardinal;


implementation

{$R *.dfm}

uses
tbicons;

procedure TForm1.mnuAboutClick(Sender: TObject);
begin
  MessageDlg('TaskbarDock v'+VERSION+RELEASENUMBER+
  #13'Author: vhanla'+
  #13'MIT License'+
  #13#13'https://github.com/vhanla/taskbardock',mtInformation, [mbOK], 0);
end;

procedure TForm1.AutoStartState;
var
  reg: TRegistry;
begin
  reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;
    reg.OpenKeyReadOnly('SOFTWARE\Microsoft\Windows\CurrentVersion\Run');
    if reg.ValueExists('TaskbarDock') then
      if reg.ReadString('TaskbarDock')<>'' then
        mnuStartwithWindows.Checked := True;
    reg.CloseKey;
  finally
    reg.Free;
  end;
end;

procedure TForm1.mnuCenterClick(Sender: TObject);
begin
  mnuCenter.Checked := not mnuCenter.Checked;
  tmrCenter.Enabled := mnuCenter.Checked;

  Taskbar.CenterAppsButtons(mnuCenter.Checked, mnuCenterRelative.Checked);
end;

procedure TForm1.Exit1Click(Sender: TObject);
begin
  CloseApp := True;
  Close;
end;

procedure TForm1.Exit2Click(Sender: TObject);
begin
  CloseApp := True;
  Close;
end;

function TForm1.FindWindowRecursive(hParent: HWND; szClass,
  szCaption: PWideChar): HWND;
begin

end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  AppIsRunning := False;
  CanClose := False;
  if CloseApp then
  begin
    tmrOptions.Enabled := False;
    Taskbar2.StartBtnVisible();
    Taskbar2.NotifyAreaVisible();
    Taskbar.StartBtnVisible();
    Taskbar.NotifyAreaVisible();

    if not ThreadIsRunning then
    begin
      SaveINI;
      Taskbar.CenterAppsButtons(False);
      Taskbar2.CenterAppsButtons(False);
      CanClose := True
    end
    else
      tmrThreadWaiter.Enabled := True;
  end
  else
  begin
    Hide;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Self.ThemeManager := ThemeManager;
  AutoStartState;
  Init;
  tmrUpdateTBinfo.Enabled := True;
  LoadINI;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  Taskbar2.Free;
  Taskbar.Free;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  ShowWindow(Application.Handle, SW_HIDE);
end;

procedure TForm1.mnuFullClick(Sender: TObject);
var
  ex: PWideChar;
begin
//  mnuFull.Checked := not mnuFull.Checked;
  //GetModuleFileName(GetWindowThreadProcessId(FindWindow('Shell_TrayWnd', nil)),ex,2048);

  InjectDLL(GetProcessIdByName('explorer.exe'),PChar(ExtractFilePath(ParamStr(0))+'TaskbarDll.dll'));
end;

function TForm1.GetProcessIdByName(s: String): DWORD;
var
  Proc: TProcessEntry32;
  hSnap: HWND;
  Looper: BOOL;
begin
  Result := 0;
  Proc.dwSize := SizeOf(Proc);
  hSnap := CreateToolhelp32Snapshot(TH32CS_SNAPALL, 0);
  Looper := Process32First(hSnap, Proc);
  while Integer(Looper) <> 0 do
  begin
    if Proc.szExeFile = s then
    begin
      Result := Proc.th32ProcessID;
      Break;
    end;
    Looper := Process32Next(hSnap, Proc);
  end;
  CloseHandle(hSnap);
end;

procedure TForm1.GetTaskbarWindows;
begin

end;

procedure TForm1.Init;
begin
  tmrCenter.Interval := 50;
  tmrUpdateTBinfo.Interval := 750;
  tmrThreadWaiter.Interval := 10;

  Taskbar := TTaskbar.Create;
  Taskbar.UpdateTaskbarInfo;
  Taskbar.TransStyle := ACCENT_ENABLE_TRANSPARENTGRADIENT;

  Taskbar2 := TTaskbar.Create(2);
  Taskbar2.UpdateTaskbarInfo;
  Taskbar2.TransStyle := ACCENT_ENABLE_TRANSPARENTGRADIENT;

  AppIsRunning := True;
  ThreadIsRunning := True;
  Parallel.Async(
    procedure
    begin
      while AppIsRunning do
      begin
        if Form1.mnuTransparent.Checked then
        begin
          Form1.Taskbar.Transparent;
          Form1.Taskbar2.Transparent;
        end;
        Sleep(10);
      end
    end,
    Parallel.TaskConfig.OnTerminated(
      procedure
      begin
        ThreadIsRunning := False;
      end
    )
  );

  fwm_TaskbarRestart := RegisterWindowMessage('TaskbarCreated');
end;

function TForm1.InjectDLL(const dwPID: DWORD; DLLPATH: PChar): Integer;
const
  Kernel32 = 'kernel32.dll';
var
  dwThreadID: Cardinal;
  hProc, hThread, hKernel: THandle;
  BytesToWrite, BytesWritten: SIZE_T;
  pRemoteBuffer, pLoadLibrary: Pointer;
begin
  hProc := OpenProcess(PROCESS_CREATE_THREAD or PROCESS_QUERY_INFORMATION or
    PROCESS_VM_OPERATION or PROCESS_VM_WRITE or PROCESS_VM_READ, False, dwPID);
  if hProc = 0 then
    Exit(0);
  try
    BytesToWrite := SizeOf(WideChar) * (Length(DLLPATH) + 1);
    pRemoteBuffer := VirtualAllocEx(hProc, nil, BytesToWrite, MEM_COMMIT,
      PAGE_READWRITE);
    if pRemoteBuffer = nil then
      Exit(0);
    try
      if not WriteProcessMemory(hProc, pRemoteBuffer, DLLPATH, BytesToWrite,
        BytesWritten) then
        Exit(0);

      hKernel := GetModuleHandle(Kernel32);
      pLoadLibrary := GetProcAddress(hKernel, 'LoadLibraryW');

      hThread := CreateRemoteThread(hProc, nil, 0, pLoadLibrary, pRemoteBuffer,
        0, dwThreadID);
      try
        WaitForSingleObject(hThread, INFINITE);
      finally
        CloseHandle(hThread);
      end;
    finally
      VirtualFreeEx(hProc, pRemoteBuffer, 0, MEM_RELEASE);
    end;
  finally
    CloseHandle(hProc);
  end;
  Exit(1);
end;

procedure TForm1.LoadINI;
var
  ini: TIniFile;
begin
  ini := TIniFile.Create(ExtractFilePath(ParamStr(0))+'settings.ini');
  try
    mnuStart.Checked := ini.ReadBool('TaskbarDock','ShowStartButton', True);
    mnuTray.Checked := ini.ReadBool('TaskbarDock','ShowTrayArea', True);
    mnuFull.Checked := ini.ReadBool('TaskbarDock','AbsoluteWidth', False);
    mnuCenter.Checked := ini.ReadBool('TaskbarDock','CenterIcons', False);
    mnuCenterRelative.Checked := ini.ReadBool('TaskbarDock','CenterRelative', False);
    tmrCenter.Enabled := mnuCenter.Checked;
    mnuTransparent.Checked := ini.ReadBool('TaskbarDock','Transparent', False);
  finally
    ini.Free;
  end;
end;

procedure TForm1.SaveINI;
var
  ini: TIniFile;
begin
  ini := TIniFile.Create(ExtractFilePath(ParamStr(0))+'settings.ini');
  try
    ini.WriteBool('TaskbarDock','ShowStartButton', mnuStart.Checked);
    ini.WriteBool('TaskbarDock','ShowTrayArea', mnuTray.Checked);
    ini.WriteBool('TaskbarDock','AbsoluteWidth', mnuFull.Checked);
    ini.WriteBool('TaskbarDock','CenterIcons', mnuCenter.Checked);
    ini.WriteBool('TaskbarDock','CenterRelative', mnuCenter.Checked);
    ini.WriteBool('TaskbarDock','Transparent', mnuTransparent.Checked);
  finally
    ini.Free;
  end;
end;

procedure TForm1.mnuPinnedIconsClick(Sender: TObject);
begin
  Form2.Show;
end;

procedure TForm1.mnuTransparentClick(Sender: TObject);
begin
  mnuTransparent.Checked := not mnuTransparent.Checked;
end;

procedure TForm1.mnuTrayClick(Sender: TObject);
begin
  mnuTray.Checked := not mnuTray.Checked;
end;

procedure TForm1.mnuCenterRelativeClick(Sender: TObject);
begin
  mnuCenterRelative.Checked := not mnuCenterRelative.Checked;
end;

procedure TForm1.SetAutoStart(runwithwindows: Boolean);
var
  reg: TRegistry;
begin
  reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;
    reg.OpenKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Run', False);
    if runwithwindows then
      reg.WriteString('TaskbarDock', ParamStr(0))
    else
      if reg.ValueExists('TaskbarDock') then
        reg.DeleteValue('TaskbarDock');
    reg.CloseKey;
  finally
    reg.Free;
  end;
end;

procedure TForm1.mnuStartClick(Sender: TObject);
begin
  mnuStart.Checked := not mnuStart.Checked;
end;

procedure TForm1.mnuStartwithWindowsClick(Sender: TObject);
begin
  mnuStartwithWindows.Checked := not mnuStartwithWindows.Checked;
  SetAutoStart(mnuStartwithWindows.Checked);
end;

procedure TForm1.tmrCenterTimer(Sender: TObject);
begin
  if tmrUpdateTBinfo.Enabled then
  begin
    Taskbar2.CenterAppsButtons(mnuCenter.Checked, mnuCenterRelative.Checked);
    Taskbar.CenterAppsButtons(mnuCenter.Checked, mnuCenterRelative.Checked);
  end;
end;

procedure TForm1.tmrOptionsTimer(Sender: TObject);
var
  sm: THandle;
  smr: TRect;
  ms: TPoint;
begin
  try
    ms := Mouse.CursorPos;
  except
  end;

  if mnuStart.Checked then
  begin
    Taskbar2.StartBtnVisible();
    Taskbar.StartBtnVisible();
  end
  else
  begin
    Taskbar2.StartBtnVisible(False);
    Taskbar.StartBtnVisible(False);
    if (ms.X >= Taskbar.StartRect.Left)
    and (ms.X <= Taskbar.StartRect.Right)
    and (ms.Y >= Taskbar.StartRect.Top)
    and (ms.Y <= Taskbar.StartRect.Bottom)
    then
      Taskbar.StartBtnVisible();
    if (ms.X >= Taskbar2.StartRect.Left)
    and (ms.X <= Taskbar2.StartRect.Right)
    and (ms.Y >= Taskbar2.StartRect.Top)
    and (ms.Y <= Taskbar2.StartRect.Bottom)
    then
      Taskbar2.StartBtnVisible();
  end;

  if mnuTray.Checked then
  begin
    Taskbar2.NotifyAreaVisible();
    Taskbar.NotifyAreaVisible();
  end
  else
  begin
    Taskbar2.NotifyAreaVisible(False);
    Taskbar.NotifyAreaVisible(False);
    if (ms.X >= Taskbar.TrayRect.Left)
    and (ms.X <= Taskbar.TrayRect.Right)
    and (ms.Y >= Taskbar.TrayRect.Top)
    and (ms.Y <= Taskbar.TrayRect.Bottom)
    then
      Taskbar.NotifyAreaVisible();

    if (ms.X >= Taskbar2.TrayRect.Left)
    and (ms.X <= Taskbar2.TrayRect.Right)
    and (ms.Y >= Taskbar2.TrayRect.Top)
    and (ms.Y <= Taskbar2.TrayRect.Bottom)
    then
      Taskbar2.NotifyAreaVisible();
  end;

  if mnuFull.Checked then
  begin
    Taskbar2.FullTaskBar;
    Taskbar.FullTaskBar;
  end;

end;

procedure TForm1.tmrThreadWaiterTimer(Sender: TObject);
begin
  if not ThreadIsRunning then
    Close
end;

procedure TForm1.tmrUpdateTBinfoTimer(Sender: TObject);
begin
  Taskbar2.UpdateTaskbarHandle;
  Taskbar2.UpdateTaskbarInfo;
  Taskbar.UpdateTaskbarInfo;
end;

procedure TForm1.TrayIcon1DblClick(Sender: TObject);
begin
  if IsWindowVisible(Self.Handle) then
    Hide
  else
    Show;
end;

procedure TForm1.UButton1Click(Sender: TObject);
begin
  CloseApp := True;
  Close
end;

procedure TForm1.USymbolButton1Click(Sender: TObject);
var
  NewPos: Integer;
  Ani: TIntAni;
  DPI: Single;
begin
  DPI := Self.PixelsPerInch / 96;
  if UPanel1.Width <> Round(45 * DPI) then
    NewPos := Round(45 * DPI)
  else
    NewPos := Round(220 * DPI);

  Ani := TIntAni.Create(akOut, afkQuartic, UPanel1.Width, NewPos,
    procedure (Value: Integer)
    begin
      UPanel1.Width := Value;
    end, True);
  Ani.Step := 20;
  Ani.Duration := 200;

  Ani.Start;
end;

procedure TForm1.WndProc(var Msg: TMessage);
begin
  if Msg.Msg = fwm_TaskbarRestart then
  begin
    Taskbar2.UpdateTaskbarHandle;
    Taskbar.UpdateTaskbarHandle;
    Taskbar2.UpdateTaskbarInfo;
    Taskbar.UpdateTaskbarInfo;
  end;

  inherited WndProc(Msg);
end;

end.
