{******************************************************************************}
{                                                                              }
{   Library:          Fundamentals 4.00                                        }
{   File name:        cTCPServer.pas                                           }
{   File version:     4.10                                                     }
{   Description:      TCP server.                                              }
{                                                                              }
{   Copyright:        Copyright (c) 2007-2012, David J Butler                  }
{                     All rights reserved.                                     }
{                     This file is licensed under the BSD License.             }
{                     See http://www.opensource.org/licenses/bsd-license.php   }
{                     Redistribution and use in source and binary forms, with  }
{                     or without modification, are permitted provided that     }
{                     the following conditions are met:                        }
{                     Redistributions of source code must retain the above     }
{                     copyright notice, this list of conditions and the        }
{                     following disclaimer.                                    }
{                     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND   }
{                     CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED          }
{                     WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED   }
{                     WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A          }
{                     PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL     }
{                     THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,    }
{                     INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR             }
{                     CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,    }
{                     PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF     }
{                     USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)         }
{                     HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER   }
{                     IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING        }
{                     NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE   }
{                     USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE             }
{                     POSSIBILITY OF SUCH DAMAGE.                              }
{                                                                              }
{   Home page:        http://fundementals.sourceforge.net                      }
{   Forum:            http://sourceforge.net/forum/forum.php?forum_id=2117     }
{   E-mail:           fundamentals.library@gmail.com                           }
{                                                                              }
{ Revision history:                                                            }
{                                                                              }
{   2007/12/01  0.01  Initial development.                                     }
{   2010/11/07  0.02  Development.                                             }
{   2010/11/12  0.03  Refactor for asynchronous operation.                     }
{   2010/12/15  0.04  TLS support.                                             }
{   2010/12/20  0.05  Option to limit the number of clients.                   }
{   2010/12/29  0.06  Indicate when client is in the negotiating state.        }
{   2010/12/30  0.07  Separate control and process threads.                    }
{   2011/06/25  0.08  Improved logging.                                        }
{   2011/07/26  0.09  Improvements.                                            }
{   2011/09/03  4.10  Revise for Fundamentals 4.                               }
{                                                                              }
{ Todo:                                                                        }
{ - Multiple processing threads                                                }
{                                                                              }
{******************************************************************************}

{$INCLUDE cTCP.inc}

unit cTCPServer;

interface

uses
  { System }
  {$IFDEF DELPHI5}
  Windows,
  {$ENDIF}
  SysUtils,
  SyncObjs,
  Classes,
  { Fundamentals }
  cSocketLib,
  cSocket,
  cTCPBuffer,
  cTCPConnection
  { TLS }
  {$IFDEF TCPSERVER_TLS},
  cTLSConnection,
  cTLSServer
  {$ENDIF}
  ;



{                                                                              }
{ TCP Server                                                                   }
{                                                                              }
const
  TCP_SERVER_DEFAULT_MaxBacklog = 8;
  TCP_SERVER_DEFAULT_MaxClients = -1;

type
  ETCPServer = class(Exception);
  
  TF4TCPServer = class;

  { TTCPServerClient                                                           }
  TTCPServerClientState = (
      scsInit,
      scsStarting,
      scsNegotiating,
      scsReady,
      scsClosed);

  TTCPServerClient = class
  protected
    FServer         : TF4TCPServer;
    FState          : TTCPServerClientState;
    FTerminated     : Boolean;
    FSocket         : TSysSocket;
    FConnection     : TTCPConnection;
    FReferenceCount : Integer;
    FOrphanClient   : Boolean;
    FClientID       : Integer;
    FUserTag        : Integer;
    FUserObject     : TObject;

    {$IFDEF TCPSERVER_TLS}
    FTLSClient      : TTLSServerClient;
    FTLSProxy       : TTCPConnectionProxy;
    {$ENDIF}

    procedure Log(const LogType: TTCPLogType; const LogMsg: String; const LogLevel: Integer = 0); overload;
    procedure Log(const LogType: TTCPLogType; const LogMsg: String; const LogArgs: array of const; const LogLevel: Integer = 0); overload;

    function  GetState: TTCPServerClientState;
    function  GetStateStr: AnsiString;
    procedure SetState(const State: TTCPServerClientState);

    {$IFDEF TCPSERVER_TLS}
    procedure InstallTLSProxy;
    {$ENDIF}

    procedure ConnectionLog(Sender: TTCPConnection; LogType: TTCPLogType; LogMsg: String; LogLevel: Integer);
    procedure ConnectionStateChange(Sender: TTCPConnection; State: TTCPConnectionState);
    procedure ConnectionRead(Sender: TTCPConnection);
    procedure ConnectionWrite(Sender: TTCPConnection);
    procedure ConnectionClose(Sender: TTCPConnection);

    procedure TriggerStateChange;
    procedure TriggerRead;    
    procedure TriggerWrite;
    procedure TriggerClose;

    procedure Start;
    procedure Process(var Idle, Terminated: Boolean);
    procedure AddReference;
    procedure SetClientOrphaned;

  public
    constructor Create(const Server: TF4TCPServer; const SocketHandle: TSocketHandle; const ClientID: Integer);
    destructor Destroy; override;

    property  State: TTCPServerClientState read GetState;
    property  StateStr: AnsiString read GetStateStr;
    property  Terminated: Boolean read FTerminated;
    property  Connection: TTCPConnection read FConnection;
    procedure Close;
    procedure ReleaseReference;

    {$IFDEF TCPSERVER_TLS}
    property  TLSClient: TTLSServerClient read FTLSClient;
    procedure StartTLS;
    {$ENDIF}
    
    property  ClientID: Integer read FClientID;

    property  UserTag: Integer read FUserTag write FUserTag;
    property  UserObject: TObject read FUserObject write FUserObject;
  end;

  TTCPServerClientClass = class of TTCPServerClient;

  { TTCPServer                                                                 }
  TTCPServerState = (
      ssInit,
      ssStarting,
      ssReady,
      ssFailure,
      ssClosed);

  TTCPServerThreadTask = (
      sttControl,
      sttProcess);

  TTCPServerThread = class(TThread)
  protected
    FServer : TF4TCPServer;
    FTask   : TTCPServerThreadTask;
    procedure Execute; override;
  public
    constructor Create(const Server: TF4TCPServer; const Task: TTCPServerThreadTask);
    property Terminated;
  end;

  TTCPServerNotifyEvent = procedure (Sender: TF4TCPServer) of object;
  TTCPServerLogEvent = procedure (Sender: TF4TCPServer; LogType: TTCPLogType;
      Msg: String; LogLevel: Integer) of object;
  TTCPServerStateEvent = procedure (Sender: TF4TCPServer; State: TTCPServerState) of object;
  TTCPServerClientEvent = procedure (Sender: TTCPServerClient) of object;
  TTCPServerIdleEvent = procedure (Sender: TF4TCPServer; Thread: TTCPServerThread) of object;
  TTCPServerAcceptEvent = procedure (Sender: TF4TCPServer; Address: TSocketAddr;
      var AcceptClient: Boolean) of object;
  TTCPServerNameLookupEvent = procedure (Sender: TF4TCPServer; Address: TSocketAddr;
      HostName: AnsiString; var AcceptClient: Boolean) of object;

  TF4TCPServer = class(TComponent)
  private
    FAddressFamily      : TIPAddressFamily;
    FBindAddressStr     : AnsiString;
    FServerPort         : Integer;
    FMaxBacklog         : Integer;
    FMaxClients         : Integer;
    FReadBufferSize     : Integer;
    FWriteBufferSize    : Integer;

    {$IFDEF TCPSERVER_TLS}
    FTLSEnabled         : Boolean;
    {$ENDIF}

    FOnLog               : TTCPServerLogEvent;
    FOnStateChanged      : TTCPServerStateEvent;
    FOnStart             : TTCPServerNotifyEvent;
    FOnStop              : TTCPServerNotifyEvent;
    FOnIdle              : TTCPServerIdleEvent;

    FOnClientAccept      : TTCPServerAcceptEvent;
    FOnClientNameLookup  : TTCPServerNameLookupEvent;
    FOnClientCreate      : TTCPServerClientEvent;
    FOnClientAdd         : TTCPServerClientEvent;
    FOnClientRemove      : TTCPServerClientEvent;
    FOnClientDestroy     : TTCPServerClientEvent;
    FOnClientStateChange : TTCPServerClientEvent;
    FOnClientRead        : TTCPServerClientEvent;
    FOnClientWrite       : TTCPServerClientEvent;
    FOnClientClose       : TTCPServerClientEvent;

    FLock               : TCriticalSection;
    FActive             : Boolean;
    FActiveOnLoaded     : Boolean;
    FState              : TTCPServerState;
    FControlThread      : TTCPServerThread;
    FProcessThread      : TTCPServerThread;
    FServerSocket       : TSysSocket;
    FBindAddress        : TSocketAddr;
    FClients            : array of TTCPServerClient;
    FClientIDCounter    : Integer;
    FIteratorDrop       : Integer;
    FIteratorProcess    : Integer;

    {$IFDEF TCPSERVER_TLS}
    FTLSServer          : TTLSServer;
    {$ENDIF}

  protected
    procedure Init; virtual;
    procedure InitDefaults; virtual;

    procedure Lock;
    procedure Unlock;

    procedure Log(const LogType: TTCPLogType; const Msg: String; const LogLevel: Integer = 0); overload;
    procedure Log(const LogType: TTCPLogType; const Msg: String; const Args: array of const; const LogLevel: Integer = 0); overload;

    function  GetState: TTCPServerState;
    function  GetStateStr: AnsiString;
    procedure SetState(const State: TTCPServerState);
    procedure CheckNotActive;

    procedure SetActive(const Active: Boolean);
    procedure Loaded; override;

    procedure SetAddressFamily(const AddressFamily: TIPAddressFamily);
    procedure SetBindAddress(const BindAddressStr: AnsiString);
    procedure SetServerPort(const ServerPort: Integer);
    procedure SetMaxBacklog(const MaxBacklog: Integer);
    procedure SetMaxClients(const MaxClients: Integer);
    procedure SetReadBufferSize(const ReadBufferSize: Integer);
    procedure SetWriteBufferSize(const WriteBufferSize: Integer);

    {$IFDEF TCPSERVER_TLS}
    procedure SetTLSEnabled(const TLSEnabled: Boolean);
    {$ENDIF}

    procedure TriggerStart; virtual;
    procedure TriggerStop; virtual;

    procedure TriggerThreadIdle(const Thread: TTCPServerThread); virtual;

    procedure ClientLog(const Client: TTCPServerClient; const LogType: TTCPLogType; const LogMsg: String; const LogLevel: Integer);

    procedure TriggerClientAccept(const Address: TSocketAddr; var AcceptClient: Boolean); virtual;
    procedure TriggerClientNameLookup(const Address: TSocketAddr; const HostName: AnsiString; var AcceptClient: Boolean); virtual;
    procedure TriggerClientCreate(const Client: TTCPServerClient); virtual;
    procedure TriggerClientAdd(const Client: TTCPServerClient); virtual;
    procedure TriggerClientRemove(const Client: TTCPServerClient); virtual;
    procedure TriggerClientDestroy(const Client: TTCPServerClient); virtual;
    procedure TriggerClientStateChange(const Client: TTCPServerClient); virtual;
    procedure TriggerClientRead(const Client: TTCPServerClient); virtual;
    procedure TriggerClientWrite(const Client: TTCPServerClient); virtual;
    procedure TriggerClientClose(const Client: TTCPServerClient); virtual;

    procedure SetReady; virtual;
    procedure SetClosed; virtual;

    procedure DoCloseClients;
    procedure DoCloseServer;
    procedure DoClose;

    {$IFDEF TCPSERVER_TLS}
    procedure TLSServerTransportLayerSendProc(Server: TTLSServer; Client: TTLSServerClient; const Buffer; const Size: Integer);
    {$ENDIF}

    procedure StartControlThread;
    procedure StartProcessThread;
    procedure StopThreads;

    procedure DoStart;
    procedure DoStop;

    function  CreateClient(const SocketHandle: TSocketHandle): TTCPServerClient; virtual;
    procedure AddClient(const Client: TTCPServerClient);
    procedure RemoveClientByIndex(const Idx: Integer);

    function  CanAcceptClient: Boolean;
    function  ServerAcceptClient: Boolean;
    function  ServerDropClient: Boolean;
    function  ServerProcessClient: Boolean;

    procedure ControlThreadExecute(const Thread: TTCPServerThread);
    procedure ProcessThreadExecute(const Thread: TTCPServerThread);
    procedure ThreadError(const Thread: TTCPServerThread; const Error: Exception);
    procedure ThreadTerminate(const Thread: TTCPServerThread);

    function  GetActiveClientCount: Integer;
    function  GetClientCount: Integer;

    function  GetReadRate: Int64;
    function  GetWriteRate: Int64;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    property  AddressFamily: TIPAddressFamily read FAddressFamily write SetAddressFamily default iaIP4;
    property  BindAddress: AnsiString read FBindAddressStr write SetBindAddress;
    property  ServerPort: Integer read FServerPort write SetServerPort;
    property  MaxBacklog: Integer read FMaxBacklog write SetMaxBacklog default TCP_SERVER_DEFAULT_MaxBacklog;
    property  MaxClients: Integer read FMaxClients write SetMaxClients default TCP_SERVER_DEFAULT_MaxClients;
    property  ReadBufferSize: Integer read FReadBufferSize write SetReadBufferSize;
    property  WriteBufferSize: Integer read FWriteBufferSize write SetWriteBufferSize;

    {$IFDEF TCPSERVER_TLS}
    property  TLSEnabled: Boolean read FTLSEnabled write SetTLSEnabled default False;
    property  TLSServer: TTLSServer read FTLSServer;
    {$ENDIF}

    property  OnLog: TTCPServerLogEvent read FOnLog write FOnLog;
    property  OnStateChanged: TTCPServerStateEvent read FOnStateChanged write FOnStateChanged;
    property  OnStart: TTCPServerNotifyEvent read FOnStart write FOnStart;
    property  OnStop: TTCPServerNotifyEvent read FOnStop write FOnStop;
    property  OnIdle: TTCPServerIdleEvent read FOnIdle write FOnIdle;
    property  OnClientAccept: TTCPServerAcceptEvent read FOnClientAccept write FOnClientAccept;
    property  OnClientCreate: TTCPServerClientEvent read FOnClientCreate write FOnClientCreate;
    property  OnClientAdd: TTCPServerClientEvent read FOnClientAdd write FOnClientAdd;
    property  OnClientRemove: TTCPServerClientEvent read FOnClientRemove write FOnClientRemove;
    property  OnClientDestroy: TTCPServerClientEvent read FOnClientDestroy write FOnClientDestroy;
    property  OnClientStateChange: TTCPServerClientEvent read FOnClientStateChange write FOnClientStateChange;
    property  OnClientRead: TTCPServerClientEvent read FOnClientRead write FOnClientRead;
    property  OnClientWrite: TTCPServerClientEvent read FOnClientWrite write FOnClientWrite;
    property  OnClientClose: TTCPServerClientEvent read FOnClientClose write FOnClientClose;

    property  State: TTCPServerState read GetState;
    property  StateStr: AnsiString read GetStateStr;
    property  Active: Boolean read FActive write SetActive default False;
    procedure Start;
    procedure Stop;

    property  ActiveClientCount: Integer read GetActiveClientCount;
    property  ClientCount: Integer read GetClientCount;
    function  GetClientReferenceByIndex(const Idx: Integer): TTCPServerClient;

    property  ReadRate: Int64 read GetReadRate;
    property  WriteRate: Int64 read GetWriteRate;
  end;



{                                                                              }
{ Components                                                                   }
{                                                                              }
type
  TFnd4TCPServer = class(TF4TCPServer)
  published
    property  Active;
    property  AddressFamily;
    property  BindAddress;
    property  ServerPort;
    property  MaxBacklog;
    property  ReadBufferSize;
    property  WriteBufferSize;

    property  OnLog;
    property  OnStateChanged;
    property  OnStart;
    property  OnStop;
    property  OnIdle;

    property  OnClientAccept;
    property  OnClientAdd;
    property  OnClientRemove;
    property  OnClientRead;
    property  OnClientWrite;
    property  OnClientClose;
  end;



implementation

{$IFDEF TCPSERVER_TLS}
uses
  { TLS }
  cTLSUtils;
{$ENDIF}



{                                                                              }
{ Error and debug strings                                                      }
{                                                                              }
const
  SError_NotAllowedWhileActive = 'Operation not allowed while server is active';
  SError_InvalidServerPort     = 'Invalid server port';

  STCPServerState : array[TTCPServerState] of AnsiString = (
      'Initialise',
      'Starting',
      'Ready',
      'Failure',
      'Closed');

  STCPServerClientState : array[TTCPServerClientState] of AnsiString = (
      'Initialise',
      'Starting',
      'Negotiating',
      'Ready',
      'Closed');

      

{$IFDEF TCPSERVER_TLS}
{                                                                              }
{ TCP Server Client TLS Connection Proxy                                       }
{                                                                              }
type
  TTCPServerClientTLSConnectionProxy = class(TTCPConnectionProxy)
  private
    FTLSServer : TTLSServer;
    FTLSClient : TTLSServerClient;

    procedure TLSClientTransportLayerSendProc(const Sender: TTLSConnection; const Buffer; const Size: Integer);
    procedure TLSClientLog(Sender: TTLSConnection; LogType: TTLSLogType; LogMsg: String; LogLevel: Integer);
    procedure TLSClientStateChange(Sender: TTLSConnection; State: TTLSConnectionState);

  public
    class function ProxyName: String; override;
    
    constructor Create(const TLSServer: TTLSServer; const Connection: TTCPConnection);
    destructor Destroy; override;

    procedure ProxyStart; override;
    procedure ProcessReadData(const Buf; const BufSize: Integer); override;
    procedure ProcessWriteData(const Buf; const BufSize: Integer); override;
  end;

class function TTCPServerClientTLSConnectionProxy.ProxyName: String;
begin
  Result := 'TLSServerClient';
end;

constructor TTCPServerClientTLSConnectionProxy.Create(const TLSServer: TTLSServer; const Connection: TTCPConnection);
begin
  Assert(Assigned(TLSServer));
  Assert(Assigned(Connection));

  inherited Create(Connection);
  FTLSServer := TLSServer;
  FTLSClient := TLSServer.AddClient(self);
  FTLSClient.OnLog := TLSClientLog;
  FTLSClient.OnStateChange := TLSClientStateChange;
end;

destructor TTCPServerClientTLSConnectionProxy.Destroy;
begin
  if Assigned(FTLSServer) and Assigned(FTLSClient) then
    FTLSServer.RemoveClient(FTLSClient);
  inherited Destroy;
end;

procedure TTCPServerClientTLSConnectionProxy.ProxyStart;
begin
  SetState(prsNegotiating);
  FTLSClient.Start;
end;

procedure TTCPServerClientTLSConnectionProxy.TLSClientTransportLayerSendProc(const Sender: TTLSConnection; const Buffer; const Size: Integer);
begin
  ConnectionPutWriteData(Buffer, Size);
end;

procedure TTCPServerClientTLSConnectionProxy.TLSClientLog(Sender: TTLSConnection; LogType: TTLSLogType; LogMsg: String; LogLevel: Integer);
begin
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, Format('TLS:%s', [LogMsg]), LogLevel + 1);
  {$ENDIF}
end;

procedure TTCPServerClientTLSConnectionProxy.TLSClientStateChange(Sender: TTLSConnection; State: TTLSConnectionState);
begin
  case State of
    tlscoApplicationData : SetState(prsFiltering);
    tlscoCancelled,
    tlscoErrorBadProtocol :
      begin
        ConnectionClose;
        SetState(prsError);
      end;
    tlscoClosed :
      begin
        ConnectionClose;
        SetState(prsClosed);
      end;
  end;
end;

procedure TTCPServerClientTLSConnectionProxy.ProcessReadData(const Buf; const BufSize: Integer);
const
  ReadBufSize = TLS_PLAINTEXT_FRAGMENT_MAXSIZE * 2;
var
  ReadBuf : array[0..ReadBufSize - 1] of Byte;
  L : Integer;
begin
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'ProcessReadData:%db', [BufSize]);
  {$ENDIF}
  FTLSClient.ProcessTransportLayerReceivedData(Buf, BufSize);
  repeat
    L := FTLSClient.AvailableToRead;
    if L > ReadBufSize then
      L := ReadBufSize;
    if L > 0 then
      begin
        L := FTLSClient.Read(ReadBuf, L);
        if L > 0 then
          ConnectionPutReadData(ReadBuf, L);
      end;
  until L <= 0;
end;

procedure TTCPServerClientTLSConnectionProxy.ProcessWriteData(const Buf; const BufSize: Integer);
begin
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'ProcessWriteData:%db', [BufSize]);
  {$ENDIF}
  FTLSClient.Write(Buf, BufSize);
end;
{$ENDIF}



{                                                                              }
{ TCP Server Client                                                            }
{                                                                              }
constructor TTCPServerClient.Create(const Server: TF4TCPServer; const SocketHandle: TSocketHandle; const ClientID: Integer);
begin
  Assert(Assigned(Server));
  Assert(SocketHandle <> INVALID_SOCKETHANDLE);

  inherited Create;
  FState := scsInit;
  FServer := Server;
  FClientID := ClientID;
  FSocket := TSysSocket.Create(Server.FAddressFamily, ipTCP, False, SocketHandle);
  FConnection := TTCPConnection.Create(FSocket);
  FConnection.OnLog         := ConnectionLog;
  FConnection.OnStateChange := ConnectionStateChange;
  FConnection.OnRead        := ConnectionRead;
  FConnection.OnWrite       := ConnectionWrite;
  FConnection.OnClose       := ConnectionClose;
  {$IFDEF TCPSERVER_TLS}
  if FServer.FTLSEnabled then
    InstallTLSProxy;
  {$ENDIF}
end;

destructor TTCPServerClient.Destroy;
begin
  FreeAndNil(FConnection);
  FreeAndNil(FSocket);
  inherited Destroy;
end;

procedure TTCPServerClient.Log(const LogType: TTCPLogType; const LogMsg: String; const LogLevel: Integer);
begin
  if Assigned(FServer) then
    FServer.ClientLog(self, LogType, LogMsg, LogLevel);
end;

procedure TTCPServerClient.Log(const LogType: TTCPLogType; const LogMsg: String; const LogArgs: array of const; const LogLevel: Integer);
begin
  Log(LogType, Format(LogMsg, LogArgs), LogLevel);
end;

function TTCPServerClient.GetState: TTCPServerClientState;
begin
  Result := FState;
end;

function TTCPServerClient.GetStateStr: AnsiString;
begin
  Result := STCPServerClientState[GetState];
end;

procedure TTCPServerClient.SetState(const State: TTCPServerClientState);
begin
  Assert(FState <> State);
  FState := State;
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'State:%s', [STCPServerClientState[State]]);
  {$ENDIF}
end;

{$IFDEF TCPSERVER_TLS}
procedure TTCPServerClient.InstallTLSProxy;
var Proxy : TTCPServerClientTLSConnectionProxy;
begin
  Assert(Assigned(FServer));

  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'InstallTLSProxy');
  {$ENDIF}
  Proxy := TTCPServerClientTLSConnectionProxy.Create(FServer.FTLSServer, FConnection);
  FTLSClient := Proxy.FTLSClient;
  FTLSProxy := Proxy;
  FConnection.AddProxy(Proxy);
end;
{$ENDIF}

procedure TTCPServerClient.ConnectionLog(Sender: TTCPConnection; LogType: TTCPLogType; LogMsg: String; LogLevel: Integer);
begin
  {$IFDEF TCP_DEBUG}
  Log(LogType, 'Connection:%s', [LogMsg], LogLevel + 1);
  {$ENDIF}
end;

procedure TTCPServerClient.ConnectionStateChange(Sender: TTCPConnection; State: TTCPConnectionState);
begin
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'Connection_StateChange:%s', [Sender.StateStr]);
  {$ENDIF}
  case State of
    cnsProxyNegotiation : SetState(scsNegotiating);
    cnsConnected        : SetState(scsReady);
  end;
  TriggerStateChange;
end;

procedure TTCPServerClient.ConnectionRead(Sender: TTCPConnection);
begin
  TriggerRead;
end;

procedure TTCPServerClient.ConnectionWrite(Sender: TTCPConnection);
begin
  TriggerWrite;
end;

procedure TTCPServerClient.ConnectionClose(Sender: TTCPConnection);
begin
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'Connection_Close');
  {$ENDIF}
  if FState = scsClosed then
    exit;
  SetState(scsClosed);
  TriggerClose;
end;

procedure TTCPServerClient.TriggerStateChange;
begin
  if Assigned(FServer) then
    FServer.TriggerClientStateChange(self);
end;

procedure TTCPServerClient.TriggerRead;
begin
  if Assigned(FServer) then
    FServer.TriggerClientRead(self);
end;

procedure TTCPServerClient.TriggerWrite;
begin
  if Assigned(FServer) then
    FServer.TriggerClientWrite(self);
end;

procedure TTCPServerClient.TriggerClose;
begin
  if Assigned(FServer) then
    FServer.TriggerClientClose(self);
end;

procedure TTCPServerClient.Start;
begin
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'Start');
  {$ENDIF}
  SetState(scsStarting);
  FConnection.Start;
end;

procedure TTCPServerClient.Process(var Idle, Terminated: Boolean);
begin
  FConnection.PollSocket(Idle, Terminated);
  if Terminated then
    FTerminated := True;
end;

procedure TTCPServerClient.AddReference;
begin
  Inc(FReferenceCount);
end;

procedure TTCPServerClient.SetClientOrphaned;
begin
  Assert(not FOrphanClient);
  Assert(Assigned(FServer));

  FOrphanClient := True;
  FServer := nil;
end;

procedure TTCPServerClient.ReleaseReference;
begin
  if FOrphanClient then
    begin
      Dec(FReferenceCount);
      if FReferenceCount = 0 then
        Free;
    end
  else
    begin
      Assert(Assigned(FServer));
      FServer.Lock;
      try
        if FReferenceCount = 0 then
          exit;
        Dec(FReferenceCount);
      finally
        FServer.Unlock;
      end;
    end;
end;

procedure TTCPServerClient.Close;
begin
  if FState = scsClosed then
    exit;
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'Close');
  {$ENDIF}
  FSocket.Close;
  SetState(scsClosed);
  TriggerClose;
end;

{$IFDEF TCPSERVER_TLS}
procedure TTCPServerClient.StartTLS;
begin
  Assert(Assigned(FServer));

  if FServer.FTLSEnabled then
    exit;
  InstallTLSProxy;
end;
{$ENDIF}



{                                                                              }
{ TCP Server Thread                                                            }
{                                                                              }
constructor TTCPServerThread.Create(const Server: TF4TCPServer; const Task: TTCPServerThreadTask);
begin
  Assert(Assigned(Server));
  FServer := Server;
  FTask := Task;
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TTCPServerThread.Execute;
begin
  Assert(Assigned(FServer));
  try
    try
      case FTask of
        sttControl : FServer.ControlThreadExecute(self);
        sttProcess : FServer.ProcessThreadExecute(self);
      end;
    except
      on E : Exception do
        FServer.ThreadError(self, E);
    end;
  finally
    FServer.ThreadTerminate(self);
  end;
end;



{                                                                              }
{ TCP Server                                                                   }
{                                                                              }
constructor TF4TCPServer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Init;
end;

procedure TF4TCPServer.Init;
begin
  FState := ssInit;
  FActiveOnLoaded := False;
  FLock := TCriticalSection.Create;
  {$IFDEF TCPSERVER_TLS}
  FTLSServer := TTLSServer.Create(TLSServerTransportLayerSendProc);
  {$ENDIF}
  InitDefaults;
end;

procedure TF4TCPServer.InitDefaults;
begin
  FActive := False;
  FAddressFamily := iaIP4;
  FBindAddressStr := '0.0.0.0';
  FMaxBacklog := TCP_SERVER_DEFAULT_MaxBacklog;
  FMaxClients := TCP_SERVER_DEFAULT_MaxClients;
  FReadBufferSize := TCP_BUFFER_DEFAULTBUFSIZE;
  {$IFDEF TCPSERVER_TLS}
  FTLSEnabled := False;
  {$ENDIF}
end;

destructor TF4TCPServer.Destroy;
var I : Integer;
    C : TTCPServerClient;
begin
  FreeAndNil(FControlThread);
  FreeAndNil(FProcessThread);
  {$IFDEF TCPSERVER_TLS}
  FreeAndNil(FTLSServer);
  {$ENDIF}
  for I := Length(FClients) - 1 downto 0 do
    begin
      C := FClients[I];
      FClients[I] := nil;
      TriggerClientRemove(C);
      if C.FReferenceCount = 0 then
        begin
          TriggerClientDestroy(C);
          C.Free;
        end
      else
        C.SetClientOrphaned;
    end;
  FClients := nil;
  FreeAndNil(FServerSocket);
  FreeAndNil(FLock);
  inherited Destroy;
end;

procedure TF4TCPServer.Lock;
begin
  FLock.Acquire;
end;

procedure TF4TCPServer.Unlock;
begin
  FLock.Release;
end;

procedure TF4TCPServer.Log(const LogType: TTCPLogType; const Msg: String; const LogLevel: Integer);
begin
  if Assigned(FOnLog) then
    FOnLog(self, LogType, Msg, LogLevel);
end;

procedure TF4TCPServer.Log(const LogType: TTCPLogType; const Msg: String; const Args: array of const; const LogLevel: Integer);
begin
  Log(LogType, Format(Msg, Args), LogLevel);
end;

function TF4TCPServer.GetState: TTCPServerState;
begin
  Lock;
  try
    Result := FState;
  finally
    Unlock;
  end;
end;

function TF4TCPServer.GetStateStr: AnsiString;
begin
  Result := STCPServerState[GetState];
end;

procedure TF4TCPServer.SetState(const State: TTCPServerState);
begin
  Lock;
  try
    Assert(FState <> State);
    FState := State;
  finally
    Unlock;
  end;
  if Assigned(FOnStateChanged) then
    FOnStateChanged(self, State);
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'State:%s', [GetStateStr]);
  {$ENDIF}
end;

procedure TF4TCPServer.CheckNotActive;
begin
  if not (csDesigning in ComponentState) then
    if FActive then
      raise ETCPServer.Create(SError_NotAllowedWhileActive);
end;

procedure TF4TCPServer.SetActive(const Active: Boolean);
begin
  if Active = FActive then
    exit;
  if csDesigning in ComponentState then
    FActive := Active else
  if csLoading in ComponentState then
    FActiveOnLoaded := Active
  else
    if Active then
      DoStart
    else
      DoStop;
end;

procedure TF4TCPServer.Loaded;
begin
  inherited Loaded;
  if FActiveOnLoaded then
    DoStart;
end;

procedure TF4TCPServer.SetAddressFamily(const AddressFamily: TIPAddressFamily);
begin
  if AddressFamily = FAddressFamily then
    exit;
  CheckNotActive;
  FAddressFamily := AddressFamily;
end;

procedure TF4TCPServer.SetBindAddress(const BindAddressStr: AnsiString);
begin
  if BindAddressStr = FBindAddressStr then
    exit;
  CheckNotActive;
  FBindAddressStr := BindAddressStr;
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'BindAddress:%s', [BindAddressStr]);
  {$ENDIF}
end;

procedure TF4TCPServer.SetServerPort(const ServerPort: Integer);
begin
  if ServerPort = FServerPort then
    exit;
  CheckNotActive;
  if (ServerPort <= 0) or (ServerPort > $FFFF) then
    raise ETCPServer.Create(SError_InvalidServerPort);
  FServerPort := ServerPort;
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'ServerPort:%d', [ServerPort]);
  {$ENDIF}
end;

procedure TF4TCPServer.SetMaxBacklog(const MaxBacklog: Integer);
begin
  if MaxBacklog = FMaxBacklog then
    exit;
  CheckNotActive;
  FMaxBacklog := MaxBacklog;
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'MaxBacklog:%d', [MaxBacklog]);
  {$ENDIF}
end;

procedure TF4TCPServer.SetMaxClients(const MaxClients: Integer);
begin
  if MaxClients = FMaxClients then
    exit;
  Lock;
  try
    FMaxClients := MaxClients;
  finally
    Unlock;
  end;
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'MaxClients:%d', [MaxClients]);
  {$ENDIF}
end;

procedure TF4TCPServer.SetReadBufferSize(const ReadBufferSize: Integer);
begin
  if ReadBufferSize = FReadBufferSize then
    exit;
  CheckNotActive;
  FReadBufferSize := ReadBufferSize;
end;

procedure TF4TCPServer.SetWriteBufferSize(const WriteBufferSize: Integer);
begin
  if WriteBufferSize = FWriteBufferSize then
    exit;
  CheckNotActive;
  FWriteBufferSize := WriteBufferSize;
end;

{$IFDEF TCPSERVER_TLS}
procedure TF4TCPServer.SetTLSEnabled(const TLSEnabled: Boolean);
begin
  if TLSEnabled = FTLSEnabled then
    exit;
  CheckNotActive;
  FTLSEnabled := TLSEnabled;
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'TLSEnabled:%d', [Ord(TLSEnabled)]);
  {$ENDIF}
end;
{$ENDIF}

procedure TF4TCPServer.TriggerStart;
begin
  if Assigned(FOnStart) then
    FOnStart(self);
end;

procedure TF4TCPServer.TriggerStop;
begin
  if Assigned(FOnStop) then
    FOnStop(self);
end;

procedure TF4TCPServer.TriggerThreadIdle(const Thread: TTCPServerThread);
begin
  if Assigned(FOnIdle) then
    FOnIdle(self, Thread)
  else
    Sleep(1);
end;

procedure TF4TCPServer.ClientLog(const Client: TTCPServerClient; const LogType: TTCPLogType; const LogMsg: String; const LogLevel: Integer);
begin
  Assert(Assigned(Client));
  {$IFDEF TCP_DEBUG}
  Log(LogType, 'Client[%d]:%s', [Client.FClientID, LogMsg], LogLevel + 1);
  {$ENDIF}
end;

procedure TF4TCPServer.TriggerClientAccept(const Address: TSocketAddr; var AcceptClient: Boolean);
begin
  if Assigned(FOnClientAccept) then
    FOnClientAccept(self, Address, AcceptClient);
end;

procedure TF4TCPServer.TriggerClientNameLookup(const Address: TSocketAddr; const HostName: AnsiString; var AcceptClient: Boolean);
begin
  if Assigned(FOnClientNameLookup) then
    FOnClientNameLookup(self, Address, HostName, AcceptClient);
end;

procedure TF4TCPServer.TriggerClientCreate(const Client: TTCPServerClient);
begin
  if Assigned(FOnClientCreate) then
    FOnClientCreate(Client);
end;

procedure TF4TCPServer.TriggerClientAdd(const Client: TTCPServerClient);
begin
  if Assigned(FOnClientAdd) then
    FOnClientAdd(Client);
end;

procedure TF4TCPServer.TriggerClientRemove(const Client: TTCPServerClient);
begin
  if Assigned(FOnClientRemove) then
    FOnClientRemove(Client);
end;

procedure TF4TCPServer.TriggerClientDestroy(const Client: TTCPServerClient);
begin
  if Assigned(FOnClientDestroy) then
    FOnClientDestroy(Client);
end;

procedure TF4TCPServer.TriggerClientStateChange(const Client: TTCPServerClient);
begin
  if Assigned(FOnClientStateChange) then
    FOnClientStateChange(Client);
end;

procedure TF4TCPServer.TriggerClientRead(const Client: TTCPServerClient);
begin
  if Assigned(FOnClientRead) then
    FOnClientRead(Client);
end;

procedure TF4TCPServer.TriggerClientWrite(const Client: TTCPServerClient);
begin
  if Assigned(FOnClientWrite) then
    FOnClientWrite(Client);
end;

procedure TF4TCPServer.TriggerClientClose(const Client: TTCPServerClient);
begin
  if Assigned(FOnClientClose) then
    FOnClientClose(Client);
end;

procedure TF4TCPServer.SetReady;
begin
  SetState(ssReady);
end;

procedure TF4TCPServer.SetClosed;
begin
  SetState(ssClosed);
end;

procedure TF4TCPServer.DoCloseClients;
var I : Integer;
begin
  for I := 0 to Length(FClients) - 1 do
    FClients[I].Close;
end;

procedure TF4TCPServer.DoCloseServer;
begin
  if Assigned(FServerSocket) then
    FServerSocket.CloseSocket;
end;

procedure TF4TCPServer.DoClose;
begin
  DoCloseServer;
  DoCloseClients;
  SetClosed;
end;

{$IFDEF TCPSERVER_TLS}
procedure TF4TCPServer.TLSServerTransportLayerSendProc(Server: TTLSServer; Client: TTLSServerClient; const Buffer; const Size: Integer);
var Proxy : TTCPServerClientTLSConnectionProxy;
begin
  Assert(Assigned(Client.UserObj));
  Assert(Client.UserObj is TTCPServerClientTLSConnectionProxy);

  Proxy := TTCPServerClientTLSConnectionProxy(Client.UserObj);
  Proxy.TLSClientTransportLayerSendProc(Client, Buffer, Size);
end;
{$ENDIF}

procedure TF4TCPServer.StartControlThread;
begin
  Assert(not Assigned(FControlThread));
  FControlThread := TTCPServerThread.Create(self, sttControl);
end;

procedure TF4TCPServer.StartProcessThread;
begin
  Assert(not Assigned(FProcessThread));
  FProcessThread := TTCPServerThread.Create(self, sttProcess);
end;

procedure TF4TCPServer.StopThreads;
begin
  FreeAndNil(FProcessThread);
  FreeAndNil(FControlThread);
end;

procedure TF4TCPServer.DoStart;
begin
  Assert(not FActive);

  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'Starting');
  {$ENDIF}
  TriggerStart;
  FActive := True;
  SetState(ssStarting);
  {$IFDEF TCPSERVER_TLS}
  if FTLSEnabled then
    FTLSServer.Start;
  {$ENDIF}
  StartControlThread;
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'Started');
  {$ENDIF}
end;

procedure TF4TCPServer.DoStop;
var I : Integer;
    C : TTCPServerClient;
begin
  Assert(FActive);

  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'Stopping');
  {$ENDIF}
  TriggerStop;
  StopThreads;
  DoClose;
  {$IFDEF TCPSERVER_TLS}
  if FTLSEnabled then
    FTLSServer.Stop;
  {$ENDIF}
  for I := Length(FClients) - 1 downto 0 do
    begin
      C := FClients[I];
      SetLength(FClients, I);
      TriggerClientRemove(C);
      if C.FReferenceCount = 0 then
        begin
          TriggerClientDestroy(C);
          C.Free;
        end
      else
        C.SetClientOrphaned;
    end;
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'Stopped');
  {$ENDIF}
  FActive := False;
end;

function TF4TCPServer.CreateClient(const SocketHandle: TSocketHandle): TTCPServerClient;
begin
  Inc(FClientIDCounter);
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'CreateClient(ID:%d,Handle:%d)', [FClientIDCounter, Ord(SocketHandle)]);
  {$ENDIF}
  Result := TTCPServerClient.Create(self, SocketHandle, FClientIDCounter);
end;

procedure TF4TCPServer.AddClient(const Client: TTCPServerClient);
var L : Integer;
begin
  Assert(Assigned(Client));

  L := Length(FClients);
  SetLength(FClients, L + 1);
  FClients[L] := Client;
end;

procedure TF4TCPServer.RemoveClientByIndex(const Idx: Integer);
var I, L : Integer;
begin
  Assert(Idx >= 0);
  Assert(Idx < Length(FClients));

  L := Length(FClients);
  for I := Idx to L - 2 do
    FClients[I] := FClients[I + 1];
  SetLength(FClients, L - 1);
end;

function TF4TCPServer.CanAcceptClient: Boolean;
var M : Integer;
begin
  Lock;
  try
    M := FMaxClients;
    if M < 0 then // no limit
      Result := True else
    if M = 0 then // paused
      Result := False
    else
      Result := Length(FClients) < M;
  finally
    Unlock;
  end;
end;

function TF4TCPServer.ServerAcceptClient: Boolean;
var AcceptAddr   : TSocketAddr;
    AcceptSocket : TSocketHandle;
    AcceptClient : Boolean;
    Client       : TTCPServerClient;
begin
  // accept socket
  AcceptSocket := FServerSocket.Accept(AcceptAddr);
  if AcceptSocket = INVALID_SOCKETHANDLE then
    begin
      Result := False;
      exit;
    end;
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, Format('IncommingConnection(%s:%d)', [
      SocketAddrIPStrA(AcceptAddr),
      AcceptAddr.Port]));
  {$ENDIF}
  AcceptClient := True;
  TriggerClientAccept(AcceptAddr, AcceptClient);
  if not AcceptClient then
    begin
      SocketClose(AcceptSocket);
      Result := False;
      exit;
    end;
  // create, add and start new client
  Lock;
  try
    Client := CreateClient(AcceptSocket);
  finally
    Unlock;
  end;
  TriggerClientCreate(Client);
  Lock;
  try
    AddClient(Client);
    Client.Start;
  finally
    Unlock;
  end;
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'ClientAdded');
  {$ENDIF}
  TriggerClientAdd(Client);
  Result := True;
end;

function TF4TCPServer.ServerDropClient: Boolean;
var I, J, L : Integer;
    C, D : TTCPServerClient;
begin
  // find next client to drop
  Lock;
  try
    D := nil;
    L := Length(FClients);
    J := FIteratorDrop;
    for I := 0 to L - 1 do
      begin
        if J >= L then
          J := 0;
        C := FClients[J];
        if C.FTerminated and (C.FReferenceCount = 0) then
          begin
            D := C;
            // remove from list
            RemoveClientByIndex(J);
            break;
          end;
        Inc(J);
      end;
    FIteratorDrop := J;
  finally
    Unlock;
  end;
  if not Assigned(D) then
    begin
      // no client to drop
      Result := False;
      exit;
    end;
  // notify and free client
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'ClientRemove');
  {$ENDIF}
  TriggerClientRemove(D);
  TriggerClientDestroy(D);
  D.Free;
  Result := True;
end;

function TF4TCPServer.ServerProcessClient: Boolean;
var I, J, L : Integer;
    C, D : TTCPServerClient;
    ClientIdle, ClientTerminated : Boolean;
begin
  // find next client to process
  Lock;
  try
    D := nil;
    L := Length(FClients);
    J := FIteratorProcess;
    for I := 0 to L - 1 do
      begin
        if J >= L then
          J := 0;
        C := FClients[J];
        Inc(J);
        if not C.FTerminated then
          begin
            D := C;
            // add reference to client to prevent removal while processing
            D.AddReference;
            break;
          end;
      end;
    FIteratorProcess := J;
  finally
    Unlock;
  end;
  if not Assigned(D) then
    begin
      // no client to process
      Result := False;
      exit;
    end;
  // process client
  try
    D.Process(ClientIdle, ClientTerminated);
  finally
    D.ReleaseReference;
  end;
  Result := not ClientIdle;
end;

procedure TF4TCPServer.ControlThreadExecute(const Thread: TTCPServerThread);

  function IsTerminated: Boolean;
  begin
    Result := Thread.Terminated;
  end;

var
  IsIdle : Boolean;
begin
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'ControlThreadExecute');
  {$ENDIF}
  Assert(FState = ssStarting);
  Assert(not Assigned(FServerSocket));
  Assert(Assigned(Thread));
  if IsTerminated then
    exit;
  // initialise server socket
  FBindAddress := ResolveHostA(FBindAddressStr, FAddressFamily);
  SetSocketAddrPort(FBindAddress, FServerPort);
  if IsTerminated then
    exit;
  FServerSocket := TSysSocket.Create(FAddressFamily, ipTCP, False, INVALID_SOCKETHANDLE);
  try
    FServerSocket.SetBlocking(True);
    FServerSocket.Bind(FBindAddress);
    FServerSocket.Listen(FMaxBacklog);
  except
    FreeAndNil(FServerSocket);
    SetState(ssFailure);
    raise;
  end;
  if IsTerminated then
    exit;
  // server socket ready
  FServerSocket.SetBlocking(False);
  SetReady;
  StartProcessThread;
  // loop until thread termination
  while not IsTerminated do
    begin
      IsIdle := True;
      // drop terminated client
      if ServerDropClient then
        IsIdle := False;
      // accept new client
      if IsTerminated then
        break;
      if CanAcceptClient then
        if ServerAcceptClient then
          IsIdle := False;
      // sleep if idle
      if IsTerminated then
        break;
      if IsIdle then
        TriggerThreadIdle(Thread);
    end;
end;

procedure TF4TCPServer.ProcessThreadExecute(const Thread: TTCPServerThread);

  function IsTerminated: Boolean;
  begin
    Result := Thread.Terminated;
  end;

var
  IsIdle : Boolean;
begin
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, 'ProcessThreadExecute');
  {$ENDIF}
  Assert(FState = ssReady);
  Assert(Assigned(Thread));
  if IsTerminated then
    exit;
  // loop until thread termination
  while not IsTerminated do
    begin
      // process clients
      IsIdle := True;
      if ServerProcessClient then
        IsIdle := False;
      // sleep if idle
      if IsTerminated then
        break;
      if IsIdle then
        TriggerThreadIdle(Thread);
    end;
end;

procedure TF4TCPServer.ThreadError(const Thread: TTCPServerThread; const Error: Exception);
begin
  Log(tlError, Format('ThreadError(Task:%d,%s,%s)', [Ord(Thread.FTask), Error.ClassName, Error.Message]));
end;

procedure TF4TCPServer.ThreadTerminate(const Thread: TTCPServerThread);
begin
  {$IFDEF TCP_DEBUG}
  Log(tlDebug, Format('ThreadTerminate(Task:%d)', [Ord(Thread.FTask)]));
  {$ENDIF}
end;

procedure TF4TCPServer.Start;
begin
  if FActive then
    exit;
  DoStart;
end;

procedure TF4TCPServer.Stop;
begin
  if not FActive then
    exit;
  DoStop;
end;

function TF4TCPServer.GetActiveClientCount: Integer;
var I, N : Integer;
    C : TTCPServerClient;
begin
  Lock;
  try
    N := 0;
    for I := 0 to Length(FClients) - 1 do
      begin
        C := FClients[I];
        if not C.FTerminated and (C.FState in [scsNegotiating, scsReady]) then
          Inc(N);  
      end;
  finally
    Unlock;
  end;
  Result := N;
end;

function TF4TCPServer.GetClientCount: Integer;
begin
  Lock;
  try
    Result := Length(FClients);
  finally
    Unlock;
  end;
end;

function TF4TCPServer.GetClientReferenceByIndex(const Idx: Integer): TTCPServerClient;
var C : TTCPServerClient;
begin
  Lock;
  try
    if (Idx < 0) or (Idx >= Length(FClients)) then
      C := nil
    else
      begin
        C := FClients[Idx];
        // add reference to prevent removal of client
        // caller must call C.ReleaseReference
        C.AddReference;
      end;
  finally
    Unlock;
  end;
  Result := C;
end;

function TF4TCPServer.GetReadRate: Int64;
var I : Integer;
    R : Int64;
    C : TTCPServerClient;
begin
  Lock;
  try
    R := 0;
    for I := 0 to Length(FClients) - 1 do
      begin
        C := FClients[I];
        if not C.FTerminated and (C.FState = scsReady) then
          Inc(R, C.Connection.ReadRate);
      end;
  finally
    Unlock;
  end;
  Result := R;
end;

function TF4TCPServer.GetWriteRate: Int64;
var I : Integer;
    R : Int64;
    C : TTCPServerClient;
begin
  Lock;
  try
    R := 0;
    for I := 0 to Length(FClients) - 1 do
      begin
        C := FClients[I];
        if not C.FTerminated and (C.FState = scsReady) then
          Inc(R, C.Connection.WriteRate);
      end;
  finally
    Unlock;
  end;
  Result := R;
end;



end.

