unit uMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  lNetComponents, lNet,LCLIntf,LCLType, Grids, Spin,
  DateUtils,
  process
  //,IdStack
  ;

const
  C_MAXBUFLEN = 32768;
  SERVERPORT = 9920;
  KLIENSPORT = 9920;

  C_MODES : array [0..8] of string= ('Temp', 'TempHűtő', 'Delta', 'Kézi', 'Idő', 'Nap', 'Hét', 'NapTemp', 'HétTemp');

type

  { TForm1 }

  TForm1 = class(TForm)
    btnSend: TButton;
    btnExit: TButton;
    btnGetAll: TButton;
    btnOn: TButton;
    btnOff: TButton;
    btnSetMode: TButton;
    btnSetPrgTemp: TButton;
    Button1: TButton;
    btnGetAllIP: TButton;
    btnSelectIP: TButton;
    cbModes: TComboBox;
    cbIPs: TComboBox;
    eIP: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    Edit4: TEdit;
    fseDeltaPrgTemp: TFloatSpinEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    sgControllers: TStringGrid;
    sgThermometers: TStringGrid;
    sePrgTemp: TSpinEdit;
    UDPSend: TLUDPComponent;
    UDPServer: TLUDPComponent;
    Memo1: TMemo;
    procedure btnExitClick(Sender: TObject);
    procedure btnGetAllClick(Sender: TObject);
    procedure btnSelectIPClick(Sender: TObject);
    procedure btnSendClick(Sender: TObject);
    procedure btnOnClick(Sender: TObject);
    procedure btnOffClick(Sender: TObject);
    procedure btnSetModeClick(Sender: TObject);
    procedure btnSetPrgTempClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure btnGetAllIPClick(Sender: TObject);
    procedure Edit4Change(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure UDPServerReceive(aSocket: TLSocket);
  private
    { private declarations }
    wServerPort, wKliensPort : word;
    procedure WriteLog(sLog:string);
    procedure MyDelay(milliSecondsDelay: int64);
    procedure UDPSendMsg(sIP:string; wPort:word; sMsg:string);
    procedure GetAllControllers;
    procedure GetAllThermometers;
    procedure AddItem(sMsg:string);
    procedure ControllerON(ID:string);
    procedure ControllerOFF(ID:string);
    procedure ControllerSetMode(ID:string; iMode:integer);
    procedure ControllerSetPrgTemp(ID:string; iNewTemp:integer; rNewDeltaTemp:real);
    procedure ControllerGetPrgTemp(ID:string);
    procedure GetAllIP;
  public
    { public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.UDPSendMsg(sIP:string; wPort:word; sMsg:string);
var PS: array[0..C_MAXBUFLEN] of Char;
  s:string;
begin
  //s:='K '+wKliensPort.ToString + ' '+ sMsg;
  s:=sMsg;
  StrPCopy(PS, s);
  UDPSend.Connect(sIP, wPort);
//  Memo1.Lines.Add('Send to '+Hova+':'+IntToStr(RPort)+' .'+strpas(ps)+'.  -  '+inttostr(strlen(ps)));
  UDPSend.Send(ps, strlen(ps)+1, sIP);
  UDPSend.Disconnect();
end;

procedure TForm1.btnExitClick(Sender: TObject);
begin
  Close;
end;

procedure TForm1.btnGetAllClick(Sender: TObject);
begin
  GetAllControllers;
  GetAllThermometers;
end;

procedure TForm1.btnSelectIPClick(Sender: TObject);
var
  sa:TStringArray;
  i:integer;
begin
  if (cbIPs.ItemIndex>=0) then begin
    sa:=cbIPs.Items[cbIPs.ItemIndex].Split('.');
    eIP.Text:=sa[0]+'.'+sa[1]+'.'+sa[2]+'.255';

  end;
end;

procedure TForm1.btnSendClick(Sender: TObject);
begin
  UDPSendMsg(eIP.Text,StrToInt(Edit2.Text), Edit3.Text);
end;

procedure TForm1.btnOnClick(Sender: TObject);
begin
  if sgControllers.Row>0 then
    ControllerON(sgControllers.Cells[0, sgControllers.Row]);
end;

procedure TForm1.btnOffClick(Sender: TObject);
begin
  if sgControllers.Row>0 then
    ControllerOFF(sgControllers.Cells[0, sgControllers.Row]);
end;

procedure TForm1.btnSetModeClick(Sender: TObject);
begin
  if sgControllers.Row>0 then
    ControllerSetMode(sgControllers.Cells[0, sgControllers.Row], cbModes.ItemIndex);
end;

procedure TForm1.btnSetPrgTempClick(Sender: TObject);
begin
  if sgControllers.Row>0 then
    ControllerSetPrgTemp(sgControllers.Cells[0, sgControllers.Row], sePrgTemp.Value, fseDeltaPrgTemp.Value);
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  if sgControllers.Row>0 then
    ControllerGetPrgTemp(sgControllers.Cells[0, sgControllers.Row]);
end;

procedure TForm1.btnGetAllIPClick(Sender: TObject);
begin
  GetAllIP;
end;

procedure TForm1.Edit4Change(Sender: TObject);
begin
  UDPServer.Disconnect();
  UDPServer.Port:=StrToInt(Edit4.Text);
  UDPServer.Listen(StrToInt(Edit4.Text));
end;


procedure TForm1.FormCreate(Sender: TObject);
var
  i:integer;
begin
  wServerPort:=SERVERPORT;
  wKliensPort:=KLIENSPORT;
  Edit4.Text:=wKliensport.ToString;
  Edit2.Text:=wServerPort.ToString;
  UDPServer.Port:=StrToInt(Edit4.Text);
  UDPServer.Listen(StrToInt(Edit4.Text));
  GetAllControllers;
  GetAllThermometers;
  for i:=0 to Length(C_MODES)-1 do cbModes.Items.Add(C_MODES[i]);
  cbModes.ItemIndex:=0;
  GetAllIP;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  UDPServer.Disconnect();
end;

procedure TForm1.UDPServerReceive(aSocket: TLSocket);
var
  s:string;
begin
  aSocket.GetMessage(s);
  s:=trim(s);
  WriteLog('UDP Receive from '+
      aSocket.PeerAddress+':'+IntToStr(aSocket.PeerPort)+' --- '+
      '('+s+')');
  AddItem(s);
end;


procedure TForm1.WriteLog(sLog:string);
begin
  Memo1.Lines.Add(FormatDateTime('YYYY.MM.DD hh:nn:ss',Now)+': '+sLog);
  Memo1.SelStart := Length(Memo1.Text);
end;

procedure TForm1.GetAllControllers;
begin
  UDPSendMsg(eIP.Text,StrToInt(Edit2.Text), '42 0');
end;

procedure TForm1.GetAllThermometers;
begin
  UDPSendMsg(eIP.Text,StrToInt(Edit2.Text), '101 0');
end;

procedure TForm1.AddItem(sMsg:string);
var
  sa:TStringArray;
  sCmd, sID:string;
  i, ind, iCmd, iID:integer;
begin
  if (Length(sMsg)>2) then begin
    sa:=sMsg.Split(' ');
    sCmd:=sa[0];
    iCmd:=sCmd.ToInteger;
    sID:=sa[1];
    iID:=sID.ToInteger;

    if (iID>0) then begin
      if ((iCmd=39) or (iCmd=43) or (iCmd=78) or (iCmd=50) or (iCmd=68)) then begin
        ind:=0;
        for i:=1 to sgControllers.RowCount-1 do begin
          if (sgControllers.Cells[0,i]=sID) then ind:=i;
        end;
        if (ind=0) then begin   //Még mincs, fel kell venni, ha van, akkor frissíteni
          sgControllers.RowCount:=sgControllers.RowCount+1;
          ind:= sgControllers.RowCount-1;
          sgControllers.Cells[0,ind] := sa[1];
          for i:=1 to 7 do begin
            if (i=1) then sgControllers.Cells[i,ind] := C_MODES[sa[i+1].ToInteger]
            else sgControllers.Cells[i,ind] := sa[i+1];
          end;
          sgControllers.SortColRow(True, 0);
        end
        else begin
          for i:=1 to 7 do begin
            if (i=1) then sgControllers.Cells[i,ind] := C_MODES[sa[i+1].ToInteger]
            else sgControllers.Cells[i,ind] := sa[i+1];
          end;
        end;

      end;
      if ((iCmd=100) or (iCmd=102) or (iCmd=104) or (iCmd=130)) then begin
        ind:=0;
        for i:=1 to sgThermometers.RowCount-1 do begin
          if (sgThermometers.Cells[0,i]=sID) then ind:=i;
        end;
        if (ind=0) then begin   //Még mincs, fel kell venni, ha van, akkor frissíteni
          sgThermometers.RowCount:=sgThermometers.RowCount+1;
          ind:= sgThermometers.RowCount-1;
          sgThermometers.Cells[0,ind] := sa[1];
          for i:=1 to 4 do begin
            sgThermometers.Cells[i,ind] := sa[i+1];
          end;
          sgThermometers.SortColRow(True, 0);
        end
        else begin
          for i:=1 to 4 do begin
            sgThermometers.Cells[i,ind] := sa[i+1];
          end;
        end;

      end;

    end;

  end;
end;

procedure TForm1.MyDelay(milliSecondsDelay: int64);
var
  stopTime : TDateTime;
begin
  stopTime := IncMilliSecond(Now,milliSecondsDelay);
  while (Now < stopTime) and (not Application.Terminated) do
    Application.ProcessMessages;
end;

procedure TForm1.ControllerON(ID:string);
begin
  UDPSendMsg(eIP.Text,StrToInt(Edit2.Text), '19 '+ID+' 3');
  MyDelay(2000);
  UDPSendMsg(eIP.Text,StrToInt(Edit2.Text), '7 '+ID+' 1');
end;

procedure TForm1.ControllerOFF(ID:string);
begin
  UDPSendMsg(eIP.Text,StrToInt(Edit2.Text), '7 '+ID+' 0');
end;

procedure TForm1.ControllerSetMode(ID:string; iMode:integer);
begin
  UDPSendMsg(eIP.Text,StrToInt(Edit2.Text), '19 '+ID+' '+iMode.ToString);
end;

procedure TForm1.ControllerSetPrgTemp(ID:string; iNewTemp:integer; rNewDeltaTemp:real);
begin
  UDPSendMsg(eIP.Text,StrToInt(Edit2.Text), '16 '+ID+' '+iNewTemp.ToString+' '+FloatToStr(rNewDeltaTemp));
end;

procedure TForm1.ControllerGetPrgTemp(ID:string);
begin
  UDPSendMsg(eIP.Text,StrToInt(Edit2.Text), '14 '+ID);
end;


procedure TForm1.GetAllIP;
var
  theProcess: TProcess;
  AddressString: AnsiString;
  sa:TStringArray;
  i:integer;
  sl: TStringList;
  sIP, sMask:string;
begin

{$IFDEF Linux}
  try
    theProcess := TProcess.Create(nil);
    theProcess.Executable := 'bash'; //'ip a | grep inet | awk ''{ print $2 }''';
    theProcess.Parameters.Add('getip.sh');//a | grep inet | awk ''{ print $2 }''');
    theProcess.Options := [poUsePipes,poWaitOnExit];
    theProcess.Execute;
    if theProcess.Output.NumBytesAvailable > 0 then
    begin
      SetLength(AddressString{%H-}, theProcess.Output.NumBytesAvailable);
      theProcess.Output.ReadBuffer(AddressString[1], theProcess.Output.NumBytesAvailable);
    end;
    //WriteLog(AddressString);
    if (Length(AddressString)>0) then begin
      sa:=AddressString.Split(#10);
      for i:=0 to Length(sa) do begin
        cbIPs.Items.Add(sa[i]);
      end;
    end;
  finally
    theProcess.Free;
  end;
{$ENDIF}

{$IFDEF MSWindows}
  sl:=TStringList.Create();
  theProcess:=TProcess.Create(nil);
  theProcess.CommandLine := 'ipconfig.exe';
  theProcess.Options := theProcess.Options + [poUsePipes, poNoConsole];
  try
    theProcess.Execute();
    Sleep(500); // poWaitOnExit not working as expected
    sl.LoadFromStream(theProcess.Output);
  finally
    theProcess.Free();
  end;
  sIP:='-';
  for i:=0 to sl.Count-1 do begin
//    if (Pos('IPv4', sl[i])=0) and (Pos('IP-', sl[i])=0) and (Pos('IP Address', sl[i])=0) then Continue;
//    sIP:=sl[i];
//    sIP:=Trim(Copy(sIP, Pos(':', sIP)+1, 999));
//    if Pos(':', sMask)>0 then Continue; // IPv6
    //Result:=Result+s+'  ';

    if (Pos('IPv4', sl[i])>0)  and (Pos('IP-', sl[i])=0) and (Pos('IP Address', sl[i])=0) then begin
      sIP:=sl[i];
      sIP:=Trim(Copy(sIP, Pos(':', sIP)+1, 999));
      if Pos(':', sIP)>0 then Continue; // IPv6
    end;
    if (sIP<>'-') and (Pos('Subnet', sl[i])>0)  and (Pos('IP-', sl[i])=0) and (Pos('IP Address', sl[i])=0) then begin
      sMask:=sl[i];
      sMask:=Trim(Copy(sMask, Pos(':', sMask)+1, 999));
      cbIPs.Items.Add(sIP+'/'+sMask);
    end;
//    if (Pos('Subnet', sl[i])=0) and (Pos('IP-', sl[i])=0) and (Pos('IP Address', sl[i])=0) then Continue;
//    sMask:=sl[i];
//    sMask:=Trim(Copy(sMask, Pos(':', sMask)+1, 999));
  end;
  sl.Free();
{$ENDIF}
  if cbIPs.Items.Count > 0 then cbIPs.ItemIndex:=0;
end;

end.

