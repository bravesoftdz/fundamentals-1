{******************************************************************************}
{                                                                              }
{   Library:          Fundamentals 4.00                                        }
{   File name:        cXMLParser.pas                                           }
{   File version:     4.07                                                     }
{   Description:      XML parser                                               }
{                                                                              }
{   Copyright:        Copyright � 2000-2011, David J Butler                    }
{                     All rights reserved.                                     }
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
{   E-mail:           fundamentalslib at gmail.com                             }
{                                                                              }
{ Revision history:                                                            }
{                                                                              }
{   11/05/2000  1.01  Created cXML from cInternetStandards.                    }
{   08/05/2001  1.02  Complete revision.                                       }
{   11/05/2001  1.03  Added DTD parser.                                        }
{   07/07/2001  1.04  Small revisions.                                         }
{   17/04/2002  2.05  Created cXMLParser from cXML.                            }
{   29/04/2002  2.06  Refactored for Unicode support.                          }
{   07/09/2003  3.07  Revised for Fundamentals 3.                              }
{                                                                              }
{******************************************************************************}

{$INCLUDE cDefines.inc}
{$IFDEF FREEPASCAL}{$IFDEF DEBUG}
  {$WARNINGS OFF}{$HINTS OFF}
{$ENDIF}{$ENDIF}
unit cXMLParser;

interface

uses
  { System }
  SysUtils,

  { Fundamentals }
  cUtils,
  cStreams,
  cUnicodeCodecs,
  cUnicode,
  cUnicodeReader,
  cXMLFunctions,
  cXMLDocument;



{                                                                              }
{ XML Parser                                                                   }
{                                                                              }
type
  TxmlParseOptions = Set of (
      xmlPreserveSpaceAroundContent,
      xmlCheckWellFormed);

const
  xmlDefaultParseOptions = [];

type
  TxmlKnownReference = record
    Reference : WideString;
    Value     : WideString;
  end;
  TxmlParser = class;
  TxmlParserObjectEvent = procedure (Sender: TxmlParser; Obj: AxmlType) of object;
  TxmlParser = class
  protected
    FOptions        : TxmlParseOptions;
    FEncoding       : AnsiString;
    FOnTag          : TxmlParserObjectEvent;
    FOnElement      : TxmlParserObjectEvent;
    FOnPI           : TxmlParserObjectEvent;
    FOnComment      : TxmlParserObjectEvent;
    FToken          : AxmlType;
    FRawString      : AnsiString;
    FRawReader      : AReaderEx;
    FRawReaderOwner : Boolean;
    FReader         : TUnicodeReader;
    FReaderOwner    : Boolean;

    function  GetCheckWellFormed: Boolean;

    procedure ParseError(const Msg: AnsiString);

    procedure GetNextToken; virtual;

    function  ParseProlog: TxmlProlog;
    function  ParseElement: AxmlElement;

    function  CreateCharData(const Text: WideString): AxmlType; virtual;
    function  CreateCharRef(const Number: LongWord; const Hex: Boolean): AxmlType; virtual;
    function  CreatePEReference(const Name: WideString): TxmlPEReference; virtual;
    function  CreateGeneralEntityRef(const Name: WideString): AxmlType; virtual;

    function  CreateAttribute(const Name: WideString; const Value: TxmlAttValue): AxmlType; virtual;
    function  CreateTextAttribute(const Name: WideString; const Value: TxmlQuotedText): AxmlType; virtual;
    function  CreateAttributeList(const TagName: WideString; const List: TxmlTypeList): AxmlAttributeList;

    function  CreateProcessingInstruction(const PITarget, Text: WideString): AxmlType;
    function  CreateComment(const Text: WideString): AxmlType; virtual;

    function  CreateStartTag(const Name: WideString; const Attributes: AxmlAttributeList): AxmlType; virtual;
    function  CreateEndTag(const Name: WideString): AxmlType; virtual;
    function  CreateEmptyElementTag(const Name: WideString; const Attributes: AxmlAttributeList): AxmlType; virtual;

    function  CreateElement(const StartTag: TxmlStartTag; const EndTag: TxmlEndTag; const Content: TxmlElementContent): AxmlElement; virtual;
    function  CreateEmptyElement(const Tag: TxmlEmptyElementTag): AxmlElement; virtual;
    function  CreateElementContent(const StartTag: TxmlStartTag): TxmlElementContent; virtual;

    function  CreateDocTypeDeclarationList: TxmlDocTypeDeclarationList; virtual;
    function  CreateDocument(const Prolog: TxmlProlog; const RootElement: AxmlElement): TxmlDocument; virtual;

    procedure ExpectChar(const Ch: AnsiChar);
    procedure ExpectAnsiStr(const S: AnsiString);
    function  ExtractName(const Required: Boolean = False): WideString;
    function  ExtractNmToken(const Required: Boolean = False): WideString;
    function  MatchSpace: Boolean;
    function  SkipSpace: Boolean;
    function  MatchSpaceDelimited(const Text: AnsiString; const SkipText: Boolean = True): Boolean;
    function  ExtractEq(const Required: Boolean = True): Boolean;
    function  ExtractTextString(const Delimiters: CharSet): WideString;
    function  ExtractText(const Delimiters: CharSet): AxmlType;
    function  ExtractPEReference: TxmlPEReference;
    function  ExtractCharRef: AxmlType;
    function  ExtractEntityRef: AxmlType;
    function  ExtractReference: AxmlType;
    procedure ExtractReferenceText(const List: TxmlTypeList; const Delimiters: CharSet; const InclPEReference: Boolean);
    function  ExtractQuote(var Quote: AnsiChar): Boolean;
    function  ExtractQuotedTextString(var Quote: AnsiChar; const Delimiters: CharSet): WideString;
    function  ExtractQuotedText(const Delimiters: CharSet): TxmlQuotedText;
    function  ExtractQuotedReferenceText(const TextClass: CxmlQuotedReferenceText; const Delimiters: CharSet; const InclPEReference: Boolean): TxmlQuotedReferenceText;
    function  ExtractTextAttribute: AxmlType;
    function  ExtractAttributeValue: TxmlAttValue;
    function  ExtractAttribute: AxmlType;
    function  ExtractAttributeList(const TagName: WideString): AxmlAttributeList;
    function  ExtractXMLDeclaration: TxmlXMLDecl;
    function  ExtractProcessingInstruction: AxmlType;
    function  ExtractQTag: AxmlType;
    function  ExtractComment: AxmlType;
    function  ExtractCDATASection: AxmlType;
    procedure ExtractNamesRest(const L: TxmlTypeList; const NmToken: Boolean; const Delimiter: AnsiChar);
    procedure ExtractNames(const L: TxmlTypeList; const NmToken: Boolean; const Delimiter: AnsiChar);
    function  ExtractElementDeclaration: AxmlType;
    function  ExtractAttDef: TxmlAttDef;
    procedure ExtractAttDefList(const L: TxmlTypeList);
    function  ExtractAttListDeclaration: AxmlType;
    function  ExtractExternalID(const NData: Boolean; const PublicID: Boolean): TxmlExternalID;
    function  ExtractEntityDeclaration: AxmlType;
    function  ExtractNotationDeclaration: AxmlType;
    function  ExtractMarkupDeclaration: AxmlType;
    function  ExtractDeclarations: TxmlDocTypeDeclarationList;
    function  ExtractDTD: AxmlType;
    function  ExtractETag: AxmlType;
    function  ExtractTag: AxmlType;

    procedure Init;

  public
    constructor Create;
    destructor Destroy; override;

    property  Options: TxmlParseOptions read FOptions write FOptions default xmlDefaultParseOptions;
    property  Encoding: AnsiString read FEncoding write FEncoding;

    property  OnTag: TxmlParserObjectEvent read FOnTag write FOnTag;
    property  OnElement: TxmlParserObjectEvent read FOnElement write FOnElement;
    property  OnPI: TxmlParserObjectEvent read FOnPI write FOnPI;
    property  OnComment: TxmlParserObjectEvent read FOnComment write FOnComment;

    procedure Clear;
    procedure SetUnicodeReader(const Reader: TUnicodeReader; const ReaderOwner: Boolean = False);
    procedure SetReader(const Reader: AReaderEx; const ReaderOwner: Boolean = False);
    procedure SetBuffer(const Buf: Pointer; const Size: Integer);
    procedure SetString(const Buf: AnsiString);
    procedure SetFileName(const FileName: AnsiString);

    function  ExtractDocument: TxmlDocument;
  end;
  ExmlParser = class(Exml);
  TxmlParserClass = class of TxmlParser;



{                                                                              }
{ Parse functions                                                              }
{                                                                              }
function  ParseXMLBuffer(const Buffer: Pointer; const Size: Integer): TxmlDocument;
function  ParseXMLString(const S: AnsiString): TxmlDocument;
function  ParseXMLFile(const FileName: AnsiString): TxmlDocument;



{                                                                              }
{ Test cases                                                                   }
{                                                                              }
{$IFDEF DEBUG}{$IFDEF SELFTEST}
procedure SelfTest;
{$ENDIF}{$ENDIF}



implementation

uses
  { Fundamentals }
  cStrings;



{                                                                              }
{ TxmlParser                                                                   }
{                                                                              }
constructor TxmlParser.Create;
begin
  inherited Create;
  Init;
end;

destructor TxmlParser.Destroy;
begin
  if FRawReaderOwner then
    FreeAndNil(FRawReader);
  if FReaderOwner then
    FreeAndNil(FReader);
  inherited Destroy;
end;

procedure TxmlParser.Init;
begin
  FOptions := xmlDefaultParseOptions;
end;

function TxmlParser.GetCheckWellFormed: Boolean;
begin
  Result := xmlCheckWellFormed in FOptions;
end;

procedure TxmlParser.Clear;
begin
  FRawString := '';
  if FRawReaderOwner then
    FreeAndNil(FRawReader) else
    FRawReader := nil;
  if FReaderOwner then
    FreeAndNil(FReader) else
    FReader := nil;
end;

procedure TxmlParser.SetUnicodeReader(const Reader: TUnicodeReader; const ReaderOwner: Boolean);
begin
  if FReaderOwner then
    FreeAndNil(FReader);
  FReader := Reader;
  FReaderOwner := ReaderOwner;
end;

procedure TxmlParser.SetReader(const Reader: AReaderEx; const ReaderOwner: Boolean);
var T    : TUnicodeCodecClass;
    B    : Array[0..1023] of Byte;
    L, N : Integer;
begin
  if FRawReaderOwner then
    FreeAndNil(FRawReader);
  FRawReader := Reader;
  FRawReaderOwner := ReaderOwner;
  if Assigned(Reader) then
    begin
      if FEncoding <> '' then
        T := GetCodecClassByAlias(FEncoding)
      else
        T := nil;
      if not Assigned(T) then
        begin
          L := Reader.Peek(B[0], Sizeof(B));
          T := xmlGetEntityEncoding(@B[0], L, N);
        end;
      SetUnicodeReader(TUnicodeReader.Create(Reader, False, T.Create, True), True);
    end
  else
    SetUnicodeReader(nil);
end;

procedure TxmlParser.SetBuffer(const Buf: Pointer; const Size: Integer);
begin
  if Assigned(Buf) and (Size > 0) then
    SetReader(TMemoryReader.Create(Buf, Size), True)
  else
    SetReader(nil, False);
end;

procedure TxmlParser.SetString(const Buf: AnsiString);
begin
  FRawString := Buf;
  SetBuffer(Pointer(FRawString), Length(FRawString));
end;

procedure TxmlParser.SetFileName(const FileName: AnsiString);
begin
  SetReader(TFileReader.Create(FileName), True);
end;

procedure TxmlParser.ParseError(const Msg: AnsiString);
begin
  raise EXMLParser.Create(Msg);
end;



{                                                                              }
{ XML STRUCTURES                                                               }
{                                                                              }
function TxmlParser.CreateCharData(const Text: WideString): AxmlType;
begin
  Result := TxmlCharData.Create(Text);
end;

function TxmlParser.CreateCharRef(const Number: LongWord; const Hex: Boolean): AxmlType;
begin
  Result := TxmlCharRef.Create(Number, Hex);
end;

function TxmlParser.CreatePEReference(const Name: WideString): TxmlPEReference;
begin
  Result := TxmlPEReference.Create(Name);
end;

function TxmlParser.CreateGeneralEntityRef(const Name: WideString): AxmlType;
begin
  Result := TxmlGeneralEntityRef.Create(Name);
end;

function TxmlParser.CreateAttribute(const Name: WideString; const Value: TxmlAttValue): AxmlType;
begin
  Result := TxmlAttribute.Create(Name, Value);
end;

function TxmlParser.CreateAttributeList(const TagName: WideString; const List: TxmlTypeList): AxmlAttributeList;
begin
  Result := TxmlAttributeList.Create(List);
end;

function TxmlParser.CreateTextAttribute(const Name: WideString; const Value: TxmlQuotedText): AxmlType;
begin
  Result := TxmlTextAttribute.Create(Name, Value);
end;

function TxmlParser.CreateProcessingInstruction(const PITarget, Text: WideString): AxmlType;
begin
  Result := TxmlProcessingInstruction.Create(PITarget, Text);
end;

function TxmlParser.CreateComment(const Text: WideString): AxmlType;
begin
  Result := TxmlComment.Create(Text);
end;

function TxmlParser.CreateStartTag(const Name: WideString; const Attributes: AxmlAttributeList): AxmlType;
begin
  Result := TxmlStartTag.Create(Name, Attributes);
end;

function TxmlParser.CreateEndTag(const Name: WideString): AxmlType;
begin
  Result := TxmlEndTag.Create(Name);
end;

function TxmlParser.CreateEmptyElementTag(const Name: WideString; const Attributes: AxmlAttributeList): AxmlType;
begin
  Result := TxmlEmptyElementTag.Create(Name, Attributes);
end;

function TxmlParser.CreateElement(const StartTag: TxmlStartTag; const EndTag: TxmlEndTag; const Content: TxmlElementContent): AxmlElement;
begin
  Result := TxmlElement.Create(StartTag, EndTag, Content);
end;

function TxmlParser.CreateEmptyElement(const Tag: TxmlEmptyElementTag): AxmlElement;
begin
  Result := TxmlEmptyElement.Create(Tag);
end;

function TxmlParser.CreateElementContent(const StartTag: TxmlStartTag): TxmlElementContent;
begin
  Result := TxmlElementContent.Create;
end;

function TxmlParser.CreateDocTypeDeclarationList: TxmlDocTypeDeclarationList;
begin
  Result := TxmlDocTypeDeclarationList.Create;
end;

function TxmlParser.CreateDocument(const Prolog: TxmlProlog; const RootElement: AxmlElement): TxmlDocument;
begin
  Result := TxmlDocument.Create(Prolog, RootElement);
end;



{                                                                              }
{ TOKENS                                                                       }
{                                                                              }
procedure TxmlParser.ExpectChar(const Ch: AnsiChar);
begin
  if not FReader.MatchWideChar(WideChar(Ch), True) then
    ParseError(Ch + ' expected');
end;

procedure TxmlParser.ExpectAnsiStr(const S: AnsiString);
begin
  if not FReader.MatchAnsiStr(S, True, True) then
    ParseError(S + ' expected');
end;

{   [3]   S ::=  (#x20 | #x9 | #xD | #xA)+                                     }
function TxmlParser.MatchSpace: Boolean;
begin
  Result := FReader.MatchChar(xmlIsSpaceChar, False);
end;

function TxmlParser.SkipSpace: Boolean;
begin
  Result := FReader.SkipAll(xmlIsSpaceChar) > 0;
end;

function TxmlParser.MatchSpaceDelimited(const Text: AnsiString; const SkipText: Boolean = True): Boolean;
begin
  Result := FReader.MatchAnsiStrDelimited(Text, True, xmlIsSpaceChar, SkipText);
end;

{   [4]   NameChar ::=  Letter | Digit | '.' | '-' | '_' | ':' |               }
{                 CombiningChar | Extender                                     }
{   [5]   Name ::=  (Letter | '_' | ':') (NameChar)*                           }
function TxmlParser.ExtractName(const Required: Boolean): WideString;
begin
  if FReader.MatchChar(xmlIsNameStartChar, False) then
    begin
      Result := FReader.ReadChar;
      Result := Result + FReader.ReadChars(xmlIsNameChar); // keep as two statements
    end else
    if Required then
      ParseError('Name expected') else
      Result := '';
end;

{   [7]   Nmtoken ::=  (NameChar)+                                             }
function TxmlParser.ExtractNmToken(const Required: Boolean): WideString;
begin
  Result := FReader.ReadChars(xmlIsNameChar);
  if Result = '' then
    if Required then
      ParseError('Name expected') else
      exit;
end;

{   [25]  Eq ::=  S? '=' S?                                                    }
function TxmlParser.ExtractEq(const Required: Boolean): Boolean;
begin
  SkipSpace;
  Result := FReader.MatchWideChar('=', True);
  if Required and not Result then
    ParseError('= expected');
  SkipSpace;
end;

{   [..]  TextString ::=  [^Delimiters]*                                       }
function TxmlParser.ExtractTextString(const Delimiters: CharSet): WideString;
begin
  Result := FReader.ReadToAnsiChar(Delimiters);
end;

{   [..]  Text ::=  TextString                                                 }
function TxmlParser.ExtractText(const Delimiters: CharSet): AxmlType;
var Text : WideString;
begin
  Text := ExtractTextString(Delimiters);
  if not (xmlPreserveSpaceAroundContent in FOptions) then
    WideTrimInPlace(Text, xmlIsSpaceChar);
  if Text = '' then
    Result := nil else
    Result := CreateCharData(Text);
end;

{   [69]  PEReference ::=  '%' Name ';'                                        }
function TxmlParser.ExtractPEReference: TxmlPEReference;
var Name : WideString;
begin
  if not FReader.MatchWideChar('%', True) then
    begin
      Result := nil;
      exit;
    end;
  Name := ExtractName(True);
  ExpectChar(';');
  Result := CreatePEReference(Name);
end;

{   [66]  CharRef ::=  '&#' [0-9]+ ';' | '&#x' [0-9a-fA-F]+ ';'                }
function TxmlParser.ExtractCharRef: AxmlType;
var Str : WideString;
    Val : LongWord;
begin
  Result := nil;
  if not FReader.MatchAnsiStr('&#', True, True) then
    exit;
  if FReader.MatchWideChar('x', True) then
    begin
      Str := FReader.ReadAnsiChars(['0'..'9', 'A'..'F', 'a'..'f']);
      if Str = '' then
        if GetCheckWellFormed then
          ParseError('Hexadecimal number expected') else
          Result := CreateCharData('&#x')
      else
        if not FReader.MatchWideChar(';', True) then
          if GetCheckWellFormed then
            ParseError('; expected') else
            Result := CreateCharData('&#x' + Str)
        else
          begin
            Val := HexToLongWord(Str);
            Result := CreateCharRef(Val, True);
          end;
    end else
    begin
      Str := FReader.ReadAnsiChars(['0'..'9']);
      if Str = '' then
        if GetCheckWellFormed then
          ParseError('Number expected') else
          Result := CreateCharData('&#')
      else
        if not FReader.MatchWideChar(';', True) then
          if GetCheckWellFormed then
            ParseError('; expected') else
            Result := CreateCharData('&#' + Str)
        else
          begin
            Val := StrToLongWord(Str);
            Result := CreateCharRef(Val, False);
          end;
    end;
end;

{   [68]  EntityRef ::=  '&' Name ';'                                          }
function TxmlParser.ExtractEntityRef: AxmlType;
var Name : WideString;
begin
  Result := nil;
  if not FReader.MatchWideChar('&', True) then
    exit;
  Name := ExtractName;
  if Name = '' then
    begin
      if GetCheckWellFormed then
        ParseError('Entity name expected') else
        Result := CreateCharData('&');
    end else
    begin
      if FReader.MatchWideChar(';', False) then
        begin
          Result := CreateGeneralEntityRef(Name);
          FReader.Skip(1);
        end else
        if GetCheckWellFormed then
          ParseError('; expected') else
          Result := CreateCharData('&' + Name);
    end;
end;

{   [67]  Reference ::=  EntityRef | CharRef                                   }
function TxmlParser.ExtractReference: AxmlType;
begin
  Result := ExtractCharRef;
  if Assigned(Result) then
    exit;
  Result := ExtractEntityRef;
end;

{   [..]  ReferenceText ::=  (Text | Reference | PEReference)*                 }
procedure TxmlParser.ExtractReferenceText(const List: TxmlTypeList; const Delimiters: CharSet; const InclPEReference: Boolean);
var C : AxmlType;
    R : Boolean;
begin
  Assert(Assigned(List));
  Repeat
    C := ExtractText(Delimiters);
    if not Assigned(C) then
      C := ExtractReference;
    if not Assigned(C) and InclPEReference then
      C := ExtractPEReference;
    R := Assigned(C);
    if R then
      List.AddChild(C);
  Until not R;
end;

{   [..]  Quote ::=  "'" | '"'                                                 }
function TxmlParser.ExtractQuote(var Quote: AnsiChar): Boolean;
var C : WideChar;
begin
  C := FReader.PeekChar;
  if (C = '''') or (C = '"') then
    begin
      FReader.Skip(1);
      Quote := AnsiChar(Ord(C));
      Result := True;
    end else
    begin
      Quote := #0;
      Result := False;
    end;
end;

{   [..]  QuotedText ::=  "'" Text "'" | '"' Text '"'                          }
function TxmlParser.ExtractQuotedTextString(var Quote: AnsiChar; const Delimiters: CharSet): WideString;
var D : CharSet;
begin
  if not ExtractQuote(Quote) then
    begin
      Result := '';
      exit;
    end;
  D := Delimiters;
  Include(D, Quote);
  Result := ExtractTextString(D);
  ExpectChar(Quote);
end;

function TxmlParser.ExtractQuotedText(const Delimiters: CharSet): TxmlQuotedText;
var Q : AnsiChar;
    T : WideString;
begin
  T := ExtractQuotedTextString(Q, Delimiters);
  if Q = #0 then
    Result := nil else
    Result := TxmlQuotedText.Create(T);
end;

{   [..]  QuotedReferenceText ::=  "'" ReferenceText "'" |                     }
{                                  '"' ReferenceText '"'                       }
function TxmlParser.ExtractQuotedReferenceText(const TextClass: CxmlQuotedReferenceText; const Delimiters: CharSet; const InclPEReference: Boolean): TxmlQuotedReferenceText;
var D : CharSet;
    C : AnsiChar;
begin
  if not ExtractQuote(C) then
    begin
      Result := nil;
      exit;
    end;
  Result := TextClass.Create;
  AssignCharSet(D, Delimiters);
  Include(D, C);
  ExtractReferenceText(Result, D, InclPEReference);
  ExpectChar(C);
end;

{   [..]  TextAttribute ::=  Name Eq QuotedText                                }
function TxmlParser.ExtractTextAttribute: AxmlType;
var Name : AnsiString;
    Val  : TxmlQuotedText;
begin
  Name := ExtractName;
  if Name = '' then
    begin
      Result := nil;
      exit;
    end;
  ExtractEq(True);
  Val := ExtractQuotedText(['<']);
  Result := CreateTextAttribute(Name, Val);
end;

{   [10]  AttValue ::=  '"' ([^<&"] | Reference)* '"'                          }
{                    |  "'" ([^<&'] | Reference)* "'"                          }
function TxmlParser.ExtractAttributeValue: TxmlAttValue;
begin
  Result := TxmlAttValue(ExtractQuotedReferenceText(TxmlAttValue, ['<'], False));
end;

{   [41]  Attribute ::=  Name Eq AttValue                                      }
function TxmlParser.ExtractAttribute: AxmlType;
var Name : WideString;
    Val  : TxmlAttValue;
begin
  Name := ExtractName;
  if Name = '' then
    begin
      Result := nil;
      exit;
    end;
  ExtractEq(True);
  Val := ExtractAttributeValue;
  Result := CreateAttribute(Name, Val);
end;

{   [..]  (S Attribute)* S?                                                    }
function TxmlParser.ExtractAttributeList(const TagName: WideString): AxmlAttributeList;
var D : AxmlType;
    L : TxmlTypeList;
    R : Boolean;
begin
  SkipSpace;
  D := ExtractAttribute;
  if not Assigned(D) then
    begin
      Result := nil;
      exit;
    end;
  L := TxmlTypeList.Create(D);
  Repeat
    SkipSpace;
    D := ExtractAttribute;
    R := Assigned(D);
    if R then
      L.AddChild(D);
  Until not R;
  Result := CreateAttributeList(TagName, L);
end;

{   [23]  XMLDecl ::=  '<?xml' VersionInfo EncodingDecl? SDDecl? S? '?>'       }
{   [24]  VersionInfo ::=  S 'version' Eq (' VersionNum ' | " VersionNum ")    }
{   [80]  EncodingDecl ::=  S 'encoding' Eq                                    }
{                           ('"' EncName '"' |  "'" EncName "'" )              }
{   [32]  SDDecl ::=  S 'standalone' Eq (("'" ('yes' | 'no') "'") |            }
{                    ('"' ('yes' | 'no') '"'))                                 }
function TxmlParser.ExtractXMLDeclaration: TxmlXMLDecl;
var C : AxmlType;
    R : Boolean;
begin
  Result := TxmlXMLDecl.Create;
  R := False;
  Repeat
    if not SkipSpace then
      R := True else
      begin
        C := ExtractTextAttribute;
        if Assigned(C) then
          Result.AddChild(C) else
          R := True;
      end;
  Until R;
  ExpectAnsiStr('?>');
end;

{   [16]  PI ::=  '<?' PITarget (S (Char* - (Char* '?>' Char*)))? '?>'         }
function TxmlParser.ExtractProcessingInstruction: AxmlType;
var Target, Text : WideString;
begin
  Target := ExtractName;
  if Target = '' then
    Result := nil else
    begin
      Text := FReader.ReadToAnsiStr('?>', True);
      ExpectAnsiStr('?>');
      Result := CreateProcessingInstruction(Target, Text);
      if Assigned(FOnPI) then
        FOnPI(self, Result);
    end;
end;

{   [23]  XMLDecl ::=  '<?xml' VersionInfo EncodingDecl? SDDecl? S? '?>'       }
{   [16]  PI ::=  '<?' PITarget (S (Char* - (Char* '?>' Char*)))? '?>'         }
function TxmlParser.ExtractQTag: AxmlType;
begin
  FReader.Skip(1);
  if FReader.MatchAnsiStr('xml', False, True) then
    Result := ExtractXMLDeclaration else
    Result := ExtractProcessingInstruction;
end;

{   [15]  Comment ::=  '<!--' ((Char - '-') | ('-' (Char - '-')))* '-->'       }
function TxmlParser.ExtractComment: AxmlType;
var S : WideString;
begin
  FReader.Skip(2);
  S := FReader.ReadToAnsiStr('-->', True);
  ExpectAnsiStr('-->');
  Result := CreateComment(S);
  if Assigned(FOnComment) then
    FOnComment(self, Result);
end;

{   [18]  CDSect ::=  CDStart CData CDEnd                                      }
{   [19]  CDStart ::=  '<![CDATA['                                             }
{   [20]  CData ::=  (Char* - (Char* ']]>' Char*))                             }
{   [21]  CDEnd ::=  ']]>'                                                     }
function TxmlParser.ExtractCDATASection: AxmlType;
var S : WideString;
begin
  FReader.Skip(7);
  S := FReader.ReadToAnsiStr(']]>', True);
  ExpectAnsiStr(']]>');
  Result := TxmlCDSect.Create(S);
end;

{   [..]  NamesRest ::=  (S? 'Delimiter' S? Name)* ')'                         }
procedure TxmlParser.ExtractNamesRest(const L: TxmlTypeList; const NmToken: Boolean; const Delimiter: AnsiChar);
var R : Boolean;
begin
  R := False;
  Repeat
    SkipSpace;
    if FReader.MatchWideChar(WideChar(Delimiter), True) then
      begin
        SkipSpace;
        if NmToken then
          L.AddChild(TxmlLiteralFormatting.Create(ExtractNmToken(True))) else
          L.AddChild(TxmlLiteralFormatting.Create(ExtractName(True)));
      end else
    if FReader.MatchWideChar(')', True) then
      R := True else
      ParseError(') expected');
  Until R;
end;

{   [..]  Names ::=  S? Name NamesRest                                         }
procedure TxmlParser.ExtractNames(const L: TxmlTypeList; const NmToken: Boolean; const Delimiter: AnsiChar);
var N : WideString;
begin
  SkipSpace;
  if FReader.MatchWideChar(WideChar(')'), True) then
    exit;
  if NmToken then
    N := ExtractNmToken else
    N := ExtractName;
  if N = '' then
    exit;
  L.AddChild(TxmlLiteralFormatting.Create(N));
  ExtractNamesRest(L, NmToken, Delimiter);
end;

{   [45]  elementdecl ::=  '<!ELEMENT' S Name S contentspec S? '>'             }
{   [46]  contentspec ::=  'EMPTY' | 'ANY' | Mixed | children                  }
{   [51]  Mixed ::=  '(' S? '#PCDATA' (S? '|' S? Name)* S? ')*'                }
{                  | '(' S? '#PCDATA' S? ')'                                   }
function TxmlParser.ExtractElementDeclaration: AxmlType;

  {   [47]  children ::=  (choice | seq) ('?' | '*' | '+')?                    }
  {   [48]  cp ::=  (Name | choice | seq) ('?' | '*' | '+')?                   }
  {   [49]  choice ::=  '(' S? cp ( S? '|' S? cp )* S? ')'                     }
  {   [50]  seq ::=  '(' S? cp ( S? ',' S? cp )* S? ')'                        }
  function ExtractChildren: AxmlListChildSpec;
  var IsChoice, IsSeq : Boolean;
      C : AxmlChildSpec;
      R : Boolean;
      Ch : AnsiChar;
  begin
    Result := nil;
    SkipSpace;
    if FReader.MatchWideChar(')', True) then
      exit;

    Ch := #0;
    IsChoice := False;
    IsSeq := False;
    try
      R := False;
      Repeat
        if FReader.MatchWideChar('(', True) then
          C := ExtractChildren else
          C := TxmlNameChildSpec.Create(ExtractName(True));
        SkipSpace;
        if FReader.MatchWideChar(',', True) then
          begin
            if IsChoice then
              ParseError('List must be either choice or seq') else
            if not IsSeq then
              begin
                IsSeq := True;
                Result := TxmlSeqChildSpec.Create;
                Result.List := TxmlTypeList.Create;
              end;
            Ch := ',';
          end else
        if FReader.MatchWideChar(WideChar('|'), True) then
          begin
            if IsSeq then
              ParseError('List must be either choice or seq') else
            if not IsChoice then
              begin
                IsChoice := True;
                Result := TxmlChoiceChildSpec.Create;
                Result.List := TxmlTypeList.Create;
              end;
            Ch := '|';
          end else
        if FReader.MatchWideChar(WideChar(')'), True) then
          begin
            if not IsChoice and not IsSeq then
              begin
                Result := TxmlSeqChildSpec.Create;
                Result.List := TxmlTypeList.Create;
              end;
            R := True;
          end else
          ParseError(') expected');

        // Parsing problem for +,?, * ???

        Result.List.AddAssigned(C);
        if not R then
          begin
            Result.List.AddAssigned(TxmlLiteralFormatting.Create(Ch));
            SkipSpace;
          end;
      Until R;
    except
      FreeAndNil(Result);
      raise;
    end;
  end;

var N : WideString;
    E : TxmlElementDeclaration;

begin
  if not MatchSpaceDelimited('<!ELEMENT') then
    begin
      Result := nil;
      exit;
    end;
  SkipSpace;
  N := ExtractName(True);
  if not SkipSpace then
    ParseError('Unexpected symbol');
  if FReader.MatchAnsiStr('EMPTY', True, True) then
    Result := TxmlElementDeclaration.Create(N, ecsEmpty) else
  if FReader.MatchAnsiStr('ANY', True, True) then
    Result := TxmlElementDeclaration.Create(N, ecsAny) else
    begin
      ExpectChar('(');
      try
        if FReader.MatchAnsiStr('#PCDATA', True, True) then
          begin
            E := TxmlElementDeclaration.Create(N, ecsMixed);
            ExtractNamesRest(TxmlMixedContentSpec(E.ContentSpec).List, False, '|');
          end else
          begin
            E := TxmlElementDeclaration.Create(N, ecsChildren);
            TxmlChildrenContentSpec(E.ContentSpec).ChildrenSpec := ExtractChildren;
          end;
        ExpectChar('>');
      except
        FreeAndNil(E);
        raise;
      end;
      Result := E;
    end;
end;

{   [..]  AttDef ::=  Name S AttType S DefaultDecl                             }
{   [54]  AttType ::=  StringType | TokenizedType | EnumeratedType             }
{   [55]  StringType ::=  'CDATA'                                              }
{   [56]  TokenizedType ::=  'ID' | 'IDREF' | 'IDREFS' | 'ENTITY'              }
{                          | 'ENTITIES' | 'NMTOKEN' | 'NMTOKENS'               }
{   [57]  EnumeratedType ::=  NotationType | Enumeration                       }
{   [58]  NotationType ::=  'NOTATION' S '(' S? Name (S? '|' S? Name)*         }
{                           S? ')'                                             }
{   [59]  Enumeration ::=  '(' S? Nmtoken (S? '|' S? Nmtoken)* S? ')'          }
{   [60]  DefaultDecl ::=  '#REQUIRED' | '#IMPLIED'                            }
{                        | (('#FIXED' S)? AttValue)                            }
function TxmlParser.ExtractAttDef: TxmlAttDef;
var N : WideString;
    P : TxmlTypeList;
    T : TxmlAttType;
    D : TxmlDefaultType;
    A : TxmlAttValue;
begin
  N := ExtractName;
  if N = '' then
    begin
      Result := nil;
      exit;
    end;
  if not SkipSpace then
    ParseError('Unexpected token');
  P := nil; A := nil; T := atNone;
  try
    if FReader.MatchWideChar('(', True) then
      begin
        T := atEnumeratedEnumerationType;
        P := TxmlTypeList.Create;
        ExtractNames(P, True, '|');
      end else
    if MatchSpaceDelimited('NOTATION') then
      begin
        T := atEnumeratedNotationType;
        SkipSpace;
        P := TxmlTypeList.Create;
        ExtractNames(P, False, '|');
      end else
    if MatchSpaceDelimited('CDATA') then
      T := atStringType else
    if MatchSpaceDelimited('ID') then
      T := atTokenizedTypeID else
    if MatchSpaceDelimited('IDREF') then
      T := atTokenizedTypeIDREF else
    if MatchSpaceDelimited('IDREFS') then
      T := atTokenizedTypeIDREFS else
    if MatchSpaceDelimited('ENTITY') then
      T := atTokenizedTypeENTITY else
    if MatchSpaceDelimited('ENTITIES') then
      T := atTokenizedTypeENTITIES else
    if MatchSpaceDelimited('NMTOKEN') then
      T := atTokenizedTypeNMTOKEN else
    if MatchSpaceDelimited('NMTOKENS') then
      T := atTokenizedTypeNMTOKENS else
      ParseError('Invalid AttType');

    SkipSpace;
    if MatchSpaceDelimited('#REQUIRED', True) then
      D := dtRequired else
    if MatchSpaceDelimited('#IMPLIED', True) then
      D := dtImplied else
      begin
        if MatchSpaceDelimited('#FIXED', True) then
          begin
            D := dtFixed;
            SkipSpace;
          end else
          D := dtValue;
        A := ExtractAttributeValue;
      end;
  except
    FreeAndNil(A);
    FreeAndNil(P);
    raise;
  end;

  Case T of
    atEnumeratedEnumerationType,
    atEnumeratedNotationType :
      Result := TxmlAttDef.Create(N, T, P, D, A);
    else
      Result := TxmlAttDef.Create(N, T, nil, D, A);
  end;
end;

{   [..]  AttDef* S?                                                           }
procedure TxmlParser.ExtractAttDefList(const L: TxmlTypeList);
begin
  Repeat
    SkipSpace;
  Until not L.AddAssigned(ExtractAttDef);
end;

{   [52]  AttlistDecl ::=  '<!ATTLIST' S Name AttDef* S? '>'                   }
function TxmlParser.ExtractAttListDeclaration: AxmlType;
var N : WideString;
begin
  if not MatchSpaceDelimited('<!ATTLIST') then
    begin
      Result := nil;
      exit;
    end;
  SkipSpace;
  N := ExtractName(True);
  Result := TxmlAttListDecl.Create(N);
  try
    ExtractAttDefList(TxmlAttListDecl(Result));
    ExpectChar('>');
  except
    FreeAndNil(Result);
    raise;
  end;
end;

{   [75]  ExternalID ::=  'SYSTEM' S SystemLiteral                           }
{                       | 'PUBLIC' S PubidLiteral S SystemLiteral            }
{   [76]  NDataDecl ::=  S 'NDATA' S Name                                    }
function TxmlParser.ExtractExternalID(const NData: Boolean; const PublicID: Boolean): TxmlExternalID;
var T, U : TxmlQuotedText;
    C    : CxmlExternalID;
begin
  if NData then
    C := TxmlExternalIDNData else
    C := TxmlExternalID;
  if not PublicID and FReader.MatchAnsiStr('SYSTEM', True, True) then
    begin
      if not SkipSpace then
        Result := nil else
        begin
          T := ExtractQuotedText([]);
          if not Assigned(T) then
            ParseError('SystemID expected');
          Result := C.CreateSystemID(T);
        end;
    end else
    Result := nil;
  if not Assigned(Result) and FReader.MatchAnsiStr('PUBLIC', True, True) then
    begin
      if not SkipSpace then
        Result := nil else
        begin
          U := nil; T := nil;
          try
            T := ExtractQuotedText([]);
            if not Assigned(T) then
              ParseError('PublicID expected');
            if not PublicID then
              begin
                if not SkipSpace then
                  ParseError('SystemID expected');
                U := ExtractQuotedText([]);
                if not Assigned(U) then
                  ParseError('SystemID expected');
              end;
          except
            FreeAndNil(T);
            FreeAndNil(U);
            raise;
          end;
          Result := C.CreatePublicID(T, U);
        end;
    end;
  if Assigned(Result) and NData then
    begin
      SkipSpace;
      if MatchSpaceDelimited('NDATA') then
        begin
          SkipSpace;
          TxmlExternalIDNData(Result).NData := ExtractName(True);
        end;
    end;
end;

{   [70]  EntityDecl ::=  GEDecl | PEDecl                                    }
{   [71]  GEDecl ::=  '<!ENTITY' S Name S EntityDef S? '>'                   }
{   [72]  PEDecl ::=  '<!ENTITY' S '%' S Name S PEDef S? '>'                 }
{   [73]  EntityDef ::=  EntityValue | (ExternalID NDataDecl?)               }
{   [74]  PEDef ::=  EntityValue | ExternalID                                }
{   [9]   EntityValue ::=  '"' ([^%&"] | PEReference | Reference)* '"'       }
{                       |  "'" ([^%&'] | PEReference | Reference)* "'"       }
function TxmlParser.ExtractEntityDeclaration: AxmlType;
var N : WideString;
    PE : Boolean;
    D : AxmlType;
begin
  if not MatchSpaceDelimited('<!ENTITY') then
    begin
      Result := nil;
      exit;
    end;
  SkipSpace;
  PE := FReader.MatchWideChar(WideChar('%'), True);
  if PE then
    SkipSpace;
  N := ExtractName(True);
  SkipSpace;
  D := ExtractExternalID(True, False);
  if not Assigned(D) then
    D := ExtractQuotedReferenceText(TxmlQuotedReferenceText, ['<'], True);
  if not Assigned(D) then
    ParseError('Entity definition expected');
  if not FReader.MatchWideChar(WideChar('>'), True) then
    ParseError('> expected');
  Result := TxmlEntityDeclaration.Create(PE, N, D);
end;

{   [82]  NotationDecl ::=  '<!NOTATION' S Name S                            }
{                           (ExternalID |  PublicID) S? '>'                  }
{   [83]  PublicID ::=  'PUBLIC' S PubidLiteral                              }
function TxmlParser.ExtractNotationDeclaration: AxmlType;
var X : TxmlExternalID;
    N : AnsiString;
begin
  if not MatchSpaceDelimited('<!NOTATION') then
    begin
      Result := nil;
      exit;
    end;
  SkipSpace;
  N := ExtractName(True);
  if not SkipSpace then
    ParseError('PublicID expected');
  X := ExtractExternalID(False, True);
  try
    SkipSpace;
    if not FReader.MatchWideChar(WideChar('>'), True) then
      ParseError('> expected');
  except
    FreeAndNil(X);
    raise;
  end;
  Result := TxmlNotationDeclaration.Create(N, X);
end;

{   [29]  markupdecl ::=  elementdecl | AttlistDecl | EntityDecl |           }
{                         NotationDecl | PI | Comment                        }
function TxmlParser.ExtractMarkupDeclaration: AxmlType;
begin
  Result := ExtractElementDeclaration;
  if Assigned(Result) then
    exit;
  Result := ExtractAttListDeclaration;
  if Assigned(Result) then
    exit;
  Result := ExtractEntityDeclaration;
  if Assigned(Result) then
    exit;
  Result := ExtractNotationDeclaration;
  if Assigned(Result) then
    exit;
  Result := ExtractProcessingInstruction;
  if Assigned(Result) then
    exit;
  if FReader.MatchAnsiStr('<!--', True, False) then
    begin
      FReader.Skip(2);
      Result := ExtractComment;
    end;
end;

{   [..]  Declarations ::=  ('[' (markupdecl | PEReference | S)* ']')? '>'   }
function TxmlParser.ExtractDeclarations: TxmlDocTypeDeclarationList;
var R : Boolean;
begin
  if not FReader.MatchWideChar('[', True) then
    begin
      Result := nil;
      exit;
    end;
  Result := CreateDocTypeDeclarationList;
  try
    R := False;
    Repeat
      if not SkipSpace then
        if not Result.AddAssigned(ExtractPEReference) then
          if not Result.AddAssigned(ExtractMarkupDeclaration) then
            if FReader.MatchWideChar(']', True) then
              R := True else
              ParseError('Unexpected token');
    Until R;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

{   [28]  doctypedecl ::=  '<!DOCTYPE' S Name (S ExternalID)? S?             }
{                        ('[' (markupdecl | PEReference | S)* ']' S?)? '>'   }
function TxmlParser.ExtractDTD: AxmlType;
var N : WideString;
    D : TxmlDocTypeDecl;
begin
  if not SkipSpace then
    begin
      Result := nil;
      exit;
    end;
  N := ExtractName(True);
  SkipSpace;
  D := TxmlDocTypeDecl.Create(N);
  try
    if D.AddAssigned(ExtractExternalID(False, False)) then
      SkipSpace;
    if D.AddAssigned(ExtractDeclarations) then
      SkipSpace;
    ExpectChar('>');
  except
    FreeAndNil(D);
    raise;
  end;
  Result := D;
end;

{   [15]  Comment ::=  '<!--' ((Char - '-') | ('-' (Char - '-')))* '-->'     }
{   [19]  CDStart ::=  '<![CDATA['                                           }
{   [28]  doctypedecl ::=  '<!DOCTYPE' S Name (S ExternalID)? S?             }
{                        ('[' (markupdecl | PEReference | S)* ']' S?)? '>'   }
function TxmlParser.ExtractETag: AxmlType;
var S : WideString;
begin
  FReader.Skip(1);
  if FReader.MatchAnsiStr('--', True, False) then
    Result := ExtractComment else
  if FReader.MatchAnsiStr('[CDATA[', True, False) then
    Result := ExtractCDATASection else
    begin
      S := FReader.ReadToAnsiChar(xmlSpace + ['[', '<', '>', '&']);
      if S = 'DOCTYPE' then
        Result := ExtractDTD else
        begin
          Result := nil;
          ParseError('Unrecognised <! tag');
        end;
    end;
end;

{   [40]  STag ::=  '<' Name (S Attribute)* S? '>'                           }
{   [42]  ETag ::=  '</' Name S? '>'                                         }
{   [44]  EmptyElemTag ::=  '<' Name (S Attribute)* S? '/>'                  }
function TxmlParser.ExtractTag: AxmlType;
var N : AnsiString;
    EmptyTag, EndTag : Boolean;
    C : AxmlAttributeList;
begin
  EndTag := FReader.MatchWideChar(WideChar('/'), True);
  N := ExtractName(True);
  C := ExtractAttributeList(N);
  try
    EmptyTag := FReader.MatchWideChar(WideChar('/'), True);
    if not FReader.MatchWideChar(WideChar('>'), True) then
      ParseError('> expected');
    if EmptyTag and EndTag then
      ParseError('Invalid tag');
    if EndTag then
      begin
        if Assigned(C) then
          ParseError('Attributes not allowed in end tag');
        Result := CreateEndTag(N);
      end else
      if EmptyTag then
        Result := CreateEmptyElementTag(N, C) else
        Result := CreateStartTag(N, C);
    if Assigned(FOnTag) then
      FOnTag(self, Result);
  except
    FreeAndNil(C);
    raise;
  end;
end;

{ Returns S, CharData, Reference, XMLDecl, PI, Comment, CDSect, STag, ETag,    }
{         EmptyElemTag                                                         }
procedure TxmlParser.GetNextToken;
var Ch : WideChar;
begin
  SkipSpace;
  if FReader.EOF then
    begin
      FToken := nil;
      exit;
    end;
  FToken := ExtractText(['<', '&']);
  if Assigned(FToken) then
    exit;
  Ch := FReader.PeekChar;
  if Ch = '&' then
    FToken := ExtractReference else
    begin
      Assert(Ch = '<', 'Unexpected character');
      FReader.Skip(1);
      Ch := FReader.PeekChar;
      if Ch = '?' then
        FToken := ExtractQTag else
      if Ch = '!' then
        FToken := ExtractETag else
        FToken := ExtractTag;
    end;
end;

{   [27]  Misc ::=  Comment | PI |  S                                          }
function IsMiscToken(const Token: AxmlType): Boolean;
begin
  Result := (Token is TxmlSpace) or (Token is TxmlComment) or
            (Token is TxmlProcessingInstruction);
end;

{   [22]  prolog ::=  XMLDecl? Misc* (doctypedecl Misc*)?                      }
function TxmlParser.ParseProlog: TxmlProlog;
var DocTypeDecl : Boolean;
    FirstToken : Boolean;
begin
  Result := nil;
  DocTypeDecl := False;
  FirstToken := True;
  try
    While IsMiscToken(FToken) or (FToken is TxmlXMLDecl) or (FToken is TxmlDocTypeDecl) do
      begin
        if FToken is TxmlXMLDecl then
          if not FirstToken then
            ParseError('XML Declaration must be first item in document prolog');
        if FToken is TxmlDocTypeDecl then
          if DocTypeDecl then
            ParseError('Duplicate Document Type Declaration (DTD)') else
            DocTypeDecl := True;
        if FirstToken then
          begin
            Result := TxmlProlog.Create;
            FirstToken := False;
          end;
        Result.AddChild(FToken);
        GetNextToken;
      end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

{   [39]  element ::=  EmptyElemTag | STag content ETag                        }
{   [43]  content ::=  (element | CharData | Reference | CDSect |              }
{                       PI | Comment)*                                         }
function TxmlParser.ParseElement: AxmlElement;
var StartTag : TxmlStartTag;
    EndTag   : TxmlEndTag;
    Content  : TxmlElementContent;
    C        : AxmlType;
    Closed   : Boolean;
begin
  if FToken is TxmlStartTag then
    begin
      StartTag := TxmlStartTag(FToken);
      GetNextToken;
      Closed := False;
      Content := nil; EndTag := nil;
      try
        Repeat
          if FToken is TxmlEndTag then
            if TxmlEndTag(FToken).Name = StartTag.Name then
              Closed := True else
              ParseError('Close tag </' + TxmlEndTag(FToken).Name + '> without matching open tag: Expected </' + StartTag.Name + '>')
          else
            begin
              if (FToken is TxmlStartTag) or (FToken is TxmlEmptyElementTag) then
                C := ParseElement else
                begin
                  C := FToken;
                  GetNextToken;
                end;
              if IsMiscToken(C) or (C is AxmlElement) or (C is TxmlCharData) or
                 (C is AxmlReference) or (C is TxmlCDSect) then
                begin
                  if not Assigned(Content) then
                    Content := CreateElementContent(StartTag);
                  Content.AddChild(C);
                end else
                ParseError('Closing tag </' + StartTag.Name + '> expected');
            end;
        Until Closed;
        EndTag := TxmlEndTag(FToken);
        GetNextToken;
      except
        FreeAndNil(StartTag);
        FreeAndNil(EndTag);
        FreeAndNil(Content);
        raise;
      end;
      Result := CreateElement(StartTag, EndTag, Content);
    end else
  if FToken is TxmlEmptyElementTag then
    begin
      Result := CreateEmptyElement(TxmlEmptyElementTag(FToken));
      GetNextToken;
    end else
    Result := nil;
  if Assigned(Result) then
    if Assigned(FOnElement) then
      FOnElement(self, Result);
end;

{   [1]  document ::=  prolog element Misc*                                    }
function TxmlParser.ExtractDocument: TxmlDocument;
var Prolog      : TxmlProlog;
    RootElement : AxmlElement;
begin
  if not Assigned(FReader) then
    ParseError('No xml text');
  GetNextToken;
  Prolog := ParseProlog;
  RootElement := ParseElement;
  if not Assigned(RootElement) then
    begin
      FreeAndNil(Prolog);
      ParseError('Document has no root element');
    end;
  Result := CreateDocument(Prolog, RootElement);
  try
    While IsMiscToken(FToken) do
      begin
        Result.AddChild(FToken);
        GetNextToken;
      end;
    if Assigned(FToken) then
      ParseError('Unexpected token');
  except
    FreeAndNil(Result);
    raise;
  end;
end;



{                                                                              }
{ Parse functions                                                              }
{                                                                              }
function ParseXMLBuffer(const Buffer: Pointer; const Size: Integer): TxmlDocument;
var P : TxmlParser;
begin
  P := TxmlParser.Create;
  try
    P.SetBuffer(Buffer, Size);
    Result := P.ExtractDocument;
  finally
    FreeAndNil(P);
  end;
end;

function ParseXMLString(const S: AnsiString): TxmlDocument;
begin
  Result := ParseXMLBuffer(Pointer(S), Length(S));
end;

function ParseXMLFile(const FileName: AnsiString): TxmlDocument;
var P : TxmlParser;
begin
  P := TxmlParser.Create;
  try
    P.SetFileName(FileName);
    Result := P.ExtractDocument;
  finally
    FreeAndNil(P);
  end;
end;



{                                                                              }
{ Test cases                                                                   }
{                                                                              }
{$IFDEF DEBUG}{$IFDEF SELFTEST}
{$ASSERTIONS ON}
procedure TestParser(const S: AnsiString);
var D : TxmlDocument;
begin
  D := ParseXMLString(S);
  try
    Assert(D.AsUTF8String([xmloNoFormatting], 0) = S, 'ParseXML');
  finally
    D.Free;
  end;
end;

procedure SelfTest;
begin
  TestParser('<A>Test</A>');
  TestParser('<A X=''AB''>Test</A>');
end;
{$ENDIF}{$ENDIF}



end.

