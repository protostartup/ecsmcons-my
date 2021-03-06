%% Copyright (c) 2012, Wes James <comptekki@gmail.com>
%% All rights reserved.
%% 
%% Redistribution and use in source and binary forms, with or without
%% modification, are permitted provided that the following conditions are met:
%% 
%%     * Redistributions of source code must retain the above copyright
%%       notice, this list of conditions and the following disclaimer.
%%     * Redistributions in binary form must reproduce the above copyright
%%       notice, this list of conditions and the following disclaimer in the
%%       documentation and/or other materials provided with the distribution.
%%     * Neither the name of "ECSMCons" nor the names of its contributors may be
%%       used to endorse or promote products derived from this software without
%%       specific prior written permission.
%% 
%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
%% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
%% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
%% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
%% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
%% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
%% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
%% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
%% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
%% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
%% POSSIBILITY OF SUCH DAMAGE.
%% 
%%

-module(ecsmcons).

-export([out/1]).

-include("/usr/local/lib/yaws/include/yaws_api.hrl").
-include("ecsmcons.hrl").

%%

fireWall(#arg{client_ip_port={PeerAddress,_Port}}) ->
	{ok, [_,{FireWallOnOff,IPAddresses},_,_,_]}=file:consult(?CONF),
	case FireWallOnOff of
		on ->
			case lists:member(PeerAddress,IPAddresses) of
				true -> allow;
				false -> deny
		    end;
		off -> allow
	end.	

%%

fwDenyMessage() ->
{content, "text/html",
["<html>
<head> 
<title>ECSMCons Login</title>
<style>
body {background-color:black; color:yellow}
</style>
</head>
<body>
Access Denied!
</body>
</html>"
]}.

%%

login() ->
	{ok, [_,_,{UPOnOff,UnamePasswds},_,_]}=file:consult(?CONF),
	case UPOnOff of
		on -> UnamePasswds;
		off -> off
	end.
	
%%

checkCreds(UnamePasswds,A) ->
	H = A#arg.headers,
	C = H#headers.cookie,
    case yaws_api:find_cookie_val("ec_logged_in", C) of
		[] ->
			case ((A#arg.req)#http_request.method) of
				'POST' ->
					case yaws_api:parse_post(A) of
						[{"uname",UnameArg},{"passwd",PasswdArg},{"login","Login"}] ->
							checkCreds(UnamePasswds,UnameArg,PasswdArg,A);
						[] -> [fail,""];
						_ -> [fail,""]
					end;
				_ -> [fail,""]
			end;
		_Cookie ->
			[Zcookie]=C,
			[CookieName,CookieValue]=string:tokens(Zcookie,"="),
			case CookieName of
				"ec_logged_in" ->
					case CookieValue of
						"true" -> [pass,""];
						_ -> [fail,""]
					end;
				_ -> [fail,""]
		   end
	end.

checkCreds([{Uname,Passwd}|UnamePasswds],Uarg,Parg,A) ->
    case Uname of
		Uarg ->
			case Passwd of
				Parg ->
					CO=yaws_api:setcookie("ec_logged_in","true","/"),
					[pass,CO];
		           _ -> checkCreds(UnamePasswds,Uarg,Parg,A)
			end;
		_ ->  checkCreds(UnamePasswds,Uarg,Parg,A)
	end;
checkCreds([],_Uarg,_Parg,_A) ->
	[fail,""].

%%

ec_login(A) ->	
	case fireWall(A) of
		allow ->
			case is_list(login()) of
				true ->
{content, "text/html",
["<html>
<head> 
<title>ECSMCons Login</title>
<link href='/static/ecsmcons.css' media='screen' rel='stylesheet' type='text/css' />
<script type='text/javascript' src='/static/jquery-1.6.4.min.js'></script>
<script>
$(document).ready(function(){

$('#uname').focus();

});
</script>
</head>
<body>
<form action='/ecsmcons' method='post'>
<div>
  <h3>Erlang Computer Management Console Login</h3>
</div>
<div class='unamed'>
  <div class='unamed-t'>Username: </div><div><input id='uname' type='text' name='uname'></div>
</div>
<div class='passwdd'>
  <div class='passwdd-t'>Password: </div><div><input id='passwd' type='password' name='passwd'></div>
</div>
<div class='logind'>
  <div class='fl'><input type='submit' name='login' value='Login'></div>
</div>
</form>
</body>
</html>" 
]};
                false ->
{content, "text/html",
["<html>
<head> 
<title>ECSMCons Login</title>
</head>
<body>
hi
</body>
</html>"
]}	                
            end;
        deny ->
            fwDenyMessage()
    end.

out(A) ->
	case fireWall(A) of
		allow ->
			P = A#arg.pathinfo,
			case P =:= "/logout" of
				true ->
					[{redirect, "/ecsmcons"},yaws_api:setcookie("ec_logged_in","","/")];
%					[ec_login(A),yaws_api:setcookie("ec_logged_in","","/")];
				false ->
					Creds=login(),
					case is_list(Creds) of
						true ->
							[Cred,CO]=checkCreds(Creds,A),
							case Cred of
								fail ->
									[ec_login(A),CO];
								pass ->
									[main_page(A),CO]
							end;
						false -> 
							case Creds of
								off ->
									main_page(A);
								_  ->
									ec_login(A)
							end
					end
			end;
		deny ->
			fwDenyMessage()
	end. % out()

%

main_page(A) ->
%	io:format("~n A: ~p ~n",[A]),
	io:format("~n clisock: ~p ~n",[A#arg.clisock]),
%	io:format("~n headers: ~p ~n",[A#arg.headers]),
	case string:tokens((A#arg.headers)#headers.host,":") of
		[Host] -> 
			Port=
				case is_tuple(A#arg.clisock) of
					true -> "80";
					_ -> "80"
				end;
		[Host,Port] -> []
	end,
	io:format("~n host: ~p port: ~p~n",[Host,Port]),
	Get_rms=get_rms_keys(?ROOMS,49),
	{ok, [_,_,_,_,{Ref_cons_time}]}=file:consult(?CONF),

	{content, "text/html",[
"<html>
<head> 
<title>ECSMCons</title> 
<link href='/static/ecsmcons.css' media='screen' rel='stylesheet' type='text/css' />
<script type='text/javascript' src='/static/jquery-1.6.4.min.js'></script>

<script>

$(document).ready(function(){

if (!window.WebSocket){
	alert('WebSocket not supported by this browser')
} else {  //The user has WebSockets

// websocket code from: http://net.tutsplus.com/tutorials/javascript-ajax/start-using-html5-websockets-today/

	var socket;
	var port='"++Port++"';
    if(port.indexOf('443')>0)
	  if (port.length>3)
		   var host='wss://"++Host++":'+port+'/ecsmcons_ws';
	  else
		 var host='wss://"++Host++"/ecsmcons_ws';
    else
		 var host='ws://"++Host++":'+port+'/ecsmcons_ws';
//alert(host);
	var r=false;
	var rall=false;
	var first=true;
    var tot_cnt=0;

	try{
		if (window.chrome)
		   var socket = new WebSocket(host)
//		  var socket = new WebSocket(host, 'binary');
		//	var socket = new WebSocket(host, 'base64')  // chrome 14+
		else
//	   		var socket = new WebSocket(host)  // safari, chrome 13

//		  var socket = new WebSocket(host, 'binary');
	var socket = new WebSocket(host, 'base64')
		message(true, socket.readyState);

		socket.onopen = function(){
			console.log('onopen called');
			send('client-connected');
			message(true, socket.readyState);

",
init_open(?ROOMS),
init2(?ROOMS,Ref_cons_time),
"
		}

		socket.onmessage = function(m){
			console.log('onmessage called');
			if (m.data)
				if(m.data.indexOf(':'>0) || m.data.indexOf('/')>0){
					if(m.data.indexOf(':')>0) {
					   boxCom=m.data.split(':');
					   sepcol=true;
					}
					else {
					   boxCom=m.data.split('/');
					   sepcol=false;
					}
					switch(boxCom[1]) {
						case 'loggedon':
							message(sepcol,boxCom[0] + ': ' + boxCom[2]);
							if (boxCom[2].indexOf('command not')<0) {
								 if(boxCom[2].length)
								     $('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').html(boxCom[2]);
							     else
							         $('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').html('Up');
                            }
                            else {
                                $('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').html('.');
							    $('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').css('color','red');
							    $('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').css('background-color','#550000');
                            }
							break;
						case 'pong':
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').css('color','green');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').css('background-color','#005500');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'_hltd').css('background-color','#005555');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'_ltd').css('background-color','#005555');
							message(sepcol,boxCom[0] + ': ' + 'pong');
							break;
					    case 'pang':
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').css('color','red');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').css('background-color','#550000');
							message(sepcol,boxCom[0] + ': ' + 'pang');
							break;
						case 'reboot':
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').css('color','red');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').css('background-color','#550000');
                            $('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').html('.');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'_hltd').css('background-color','#000000');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'_ltd').css('background-color','#000000');
							break;
					    case 'shutdown':
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').css('color','red');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').css('background-color','#550000');
                            $('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').html('.');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'_hltd').css('background-color','#000000');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'_ltd').css('background-color','#000000');
							break;
					    case 'dffreeze':
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'dfstatus').css('color','cyan');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'dfstatus').css('background-color','#006666');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').css('color','red');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').css('background-color','#550000');
                            $('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').html('.');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'_hltd').css('background-color','#000000');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'_ltd').css('background-color','#000000');
							break;
					    case 'dfthaw':
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'dfstatus').css('color','green');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'dfstatus').css('background-color','#006600');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').css('color','red');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').css('background-color','#550000');
                            $('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').html('.');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'_hltd').css('background-color','#000000');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'_ltd').css('background-color','#000000');
							break;
					    case 'dfstatus':
							if(!(boxCom[2].indexOf('thawed'))){
								$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'dfstatus').html('DF');
								$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'dfstatus').css('color','green');
								$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'dfstatus').css('background-color','#006600');
							}
							else {
								$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'dfstatus').html('DF');
								$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'dfstatus').css('color','cyan');
								$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'dfstatus').css('background-color','#006666');
							}
							break;
					    case 'copy':
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').css('color','#00cc00');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').css('background-color','#006600');
							message(sepcol,boxCom[0] + ': ' + 'copy');
							break;
					    case 'com':
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').css('color','#00cc00');
							$('#'+boxCom[0].substr(0,boxCom[0].indexOf('.'))+'status').css('background-color','#006600');
							message(sepcol,boxCom[0] + ': ' + 'com');
							break;
					    default:
                            if(boxCom[2])
							    message(sepcol,boxCom[0] + ': ' + boxCom[1] + ' ' + boxCom[2])
                            else
							    message(sepcol,boxCom[0] + ': ' + boxCom[1])
					}
				}
				else message(true,m.data)
		}

		socket.onclose = function(){
			console.log('onclose called')
		    message(true,'Socket status: 3 (Closed)');
		}

		socket.onerror = function(e){
			message(true,'Socket Status: '+e.data)
		}

	} catch(exception){
	   message(true,'Error'+exception)
	}

	function send(msg){
		console.log('send called');
		if(msg == null || msg.length == 0){
			message(true,'No data....');
			return
		}
		try{
			socket.send(msg)
		} catch(exception){
			message(true,'Error'+exception)
		}
	}

	function message(sepcol,msg){
        var jsnow = new Date();
        var month=jsnow.getMonth()+1;
        var day=jsnow.getDate();
        var hour=jsnow.getHours();
        var mins=jsnow.getMinutes();
        var seconds=jsnow.getSeconds();

        (month<10)?month='0'+month:month;
        (day<10)?day='0'+day:day;
        (hour<10)?hour='0'+hour:hour;
        (mins<10)?mins='0'+mins:mins;
        (seconds<10)?seconds='0'+seconds:seconds;

        now = month+'/'+day+'/'+jsnow.getFullYear()+'-'+hour+':'+mins+':'+seconds;
        
		if (isNaN(msg)) {
            if(sepcol)
			    $('#msg').html(now+':'+msg+'<br>'+$('#msg').html())
            else
			    $('#msgcl').html(now+':'+msg+'<br>'+$('#msgcl').html())
        }
		else
			$('#msg').html(now+':'+socket_status(msg)+'<br>'+$('#msg').html())
	}

	function socket_status(readyState){
		if (readyState == 0)
			return 'Socket status: ' + socket.readyState +' (Connecting)'
		else if (readyState == 1)
			return 'Socket status: ' + socket.readyState + ' (Open)'
		else if (readyState == 2)
			return 'Socket status: ' + socket.readyState + ' (Closing)'
		else if (readyState == 3)
			return 'Socket status: ' + socket.readyState +' (Closed)'
	}

	$('#disconnect').click(function(){
        send('close')
	});

",
jsAll(?ROOMS,"ping"),
jsAllConfirm(?ROOMS,"reboot"),
jsAllConfirm(?ROOMS,"shutdown"),
jsAllConfirm(?ROOMS,"dfthaw"),
jsAllConfirm(?ROOMS,"dffreeze"),
jsAll(?ROOMS,"wake"),
jsAll(?ROOMS,"dfstatus"),
jsAll(?ROOMS,"net_restart"),
jsAll(?ROOMS,"net_stop"),
jsAll(?ROOMS,"loggedon"),
jsAll(?ROOMS,"copy"),
jsAll(?ROOMS,"com"),
mkjsAllSelect_copy(?ROOMS),
mkjsSelect_copy(?ROOMS),
mkjsAllSelect_com(?ROOMS),
mkjsSelect_com(?ROOMS),
mkjsSelectAllChk(?ROOMS),
mkjsUnSelectAllChk(?ROOMS),
mkjsToggleAllChk(?ROOMS),
mkcomButtons(?ROOMS),
mkjsComAll(?ROOMS,"ping"),
mkjsComAll(?ROOMS,"reboot"),
mkjsComAll(?ROOMS,"shutdown"),
mkjsComAll(?ROOMS,"wake"),
mkjsComAll(?ROOMS,"dfthaw"),
mkjsComAll(?ROOMS,"dffreeze"),
mkjsComAll(?ROOMS,"dfstatus"),
mkjsComAll(?ROOMS,"net_restart"),
mkjsComAll(?ROOMS,"net_stop"),
mkjsComAll(?ROOMS,"loggedon"),
mkjsComAll(?ROOMS,"copy"),
mkjsComAll(?ROOMS,"com"),
chk_dupe_usersa(?ROOMS),
chk_dupe_users(?ROOMS),
refresh_cons(?ROOMS),
toggles(?ROOMS),
rms_keys(Get_rms,Get_rms),
"

    interval_chk_dupes=setInterval(chk_dupe_users,60000);

}//End else - has websockets

});

</script>
 
</head>

<body>
<div id='wrapper'>

<div id='menu' class='fl'>

<div id='rooms_title' class='fl'>
[0]-Rooms 
</div>

<div id='switcher'>
",
switcher(?ROOMS),
"
</div>

</div>

 <div class='brk'></div>

 <div id='commands'>

 <div id='com_title'>
 Commands
 </div>

 <div id='tcoms'>",
 case is_list(login()) of
	 true -> "<a href='ecsmcons/logout' id='logout' class='button' />Logout</a><br>";
	 false -> ""
 end,
 "
 <a href=# id='disconnect' class='button' />Disconnect</a><br>
 ",
 mkAllRoomsComs([
				 {"ping","Ping All"},
				 {"reboot","Reboot All"},
				 {"shutdown","Shutdown All"},
				 {"wake","Wake All"},
				 {"dfthaw","DeepFreeze Thaw All"},
				 {"dffreeze","DeepFreeze Freeze All"},
				 {"dfstatus","DeepFreeze Status All"},
				 {"net_restart","Restart Win Service All"},
				 {"net_stop","Stop Win Service All"},
				 {"loggedon","Logged On All"}
				]),
 "
 </div>

 <div id='tinputs'>
 ",
 mkAllRoomsComsInput({"copy","Copy All"}),
 mkAllRoomsComsInput({"com","Com All"}),
 mkAllRoomsSelectUnselectToggleAll(?ROOMS),
 "
 </div>

 <div id='tmsgs' class='tmsgsc'>
   <div id='mtop' class='mtopc'>Server Messages (most recent at top):</div>
	 <div id='msg-div'>
	 <div id='msg' class='msgc'></div>
   </div>
 </div>

 <div id='tmsgscl' class='tmsgsc'>
   <div id='mtopcl' class='mtopc'>Client Messages (most recent at top):</div>
	 <div id='msg-divcl'>
	 <div id='msgcl' class='msgc'></div>
   </div>
 </div>

 <div id='tmsgsdup' class='tmsgsc'>
   <div id='mtopdup' class='mtopcd'>Duplicate Users (most recent at top):</div>
	 <div id='msg-div-dup'>
	 <div id='msgdup' class='msgcd'></div>
   </div>
 </div>

 </div>

 <div class='brk'></div>

 <div id='workstations'>

 ",
 mkRooms(?ROOMS),
 "

 </div>

 </div>

 </body> 
 </html>
 "
 ]
}. % main_page()

 %%

 init_open([Room|_]) ->
	 [Rm|_]=Room,

 [
 "
					  $('#"++Rm++"').show();
					  $('#"++Rm++"_coms').show();
					  $('#"++Rm++"_comsInputcopy').show();
					  $('#"++Rm++"_comsInputcom').show();

					  $('#"++Rm++"_selunseltogall').show();

                      $('#"++Rm++"toggle').click();
					  $('#"++Rm++"toggle').focus();

 "].

 %%

 toggles([Room|Rooms]) ->
	 [toggles_rm(Room)|toggles(Rooms)];
 toggles([]) ->
	 [].

 toggles_rm([Rm|_]) ->
	 [
 "
	 $('#"++Rm++"toggle').click(function(){
 ",
 toggle_items(?ROOMS,Rm),
 "
	 });
 "].

 toggle_items([Room|Rooms],Rm) ->
	 [toggle_item(Room,Rm)|toggle_items(Rooms,Rm)];
 toggle_items([],_) ->
	 [].

 toggle_item([Room|_],Rm) ->
	 [
	  case Room of

		  Rm ->
 ["
		 $('#"++Rm++"').show();
		 $('#"++Rm++"_coms').show();
		 $('#"++Rm++"_comsInputcopy').show();
		 $('#"++Rm++"_comsInputcom').show();
 	     $('#"++Rm++"_selunseltogall').show();
		 $('#"++Rm++"toggle').removeClass('rm_selected');
		 $('#"++Rm++"toggle').removeClass('rm_not_selected');
		 $('#"++Rm++"toggle').addClass('rm_selected');
 "];
		  _ -> 
 ["
		 $('#"++Room++"').hide();
		 $('#"++Room++"_coms').hide();
		 $('#"++Room++"_comsInputcopy').hide();
		 $('#"++Room++"_comsInputcom').hide();
	     $('#"++Room++"_selunseltogall').hide();
		 $('#"++Room++"toggle').removeClass('rm_selected');
		 $('#"++Room++"toggle').removeClass('rm_not_selected');
		 $('#"++Room++"toggle').addClass('rm_not_selected')

 "]
	  end
	 ];

 toggle_item([],_) ->
	 [].

 %%

 jsAll([Room|Rooms],Com) ->
	 [Rm|_]=Room,
	 [

 case Com of
	 "com"  -> ifcomcopy(Rm,Com);
	 "copy" -> ifcomcopy(Rm,Com);
		  _ ->
 ["

	 $('#",Com,"All",Rm,"').click(function(){
			 ",Com,"All",Rm,"();
			 message(true,'",Com," All ",Rm,"...')
	 });

 "]
 end
 |jsAll(Rooms,Com)];
 jsAll([],_) -> [].

 %%

 ifcomcopy(Rm,Com) ->
 ["
	 $('#",Com,"All",Rm,"').click(function(){
		 if($('#",Com,"AllInput",Rm,"').val().length){
			 ",Com,"All",Rm,"();
			 message(true,'",Com," All ",Rm,"...')
		 } else {
			 $('#",Com,"AllInput",Rm,"').val('!');
			 message(true,'",Com," All ",Rm," is blank!')
		 }
	 });

 "].

 %%

 jsAllConfirm([Room|Rooms],Com) ->
	 [Rm|_]=Room,
	 [
 "

	 $('#"++Com++"All"++Rm++"').click(function(){
		 rall=confirm('"++Com++" All Systems "++Rm++"?');
		 if (rall==true)
			 "++Com++"All"++Rm++"()
		 else
			 message(true,'"++Com++" All in "++Rm++" aborted...')
	 });

 "|jsAllConfirm(Rooms,Com)];
 jsAllConfirm([],_) -> [].

 %%

 mkjsAllSelect_copy([Room|Rooms]) ->
	 [mkjsAllSelectRm_copy(Room)|mkjsAllSelect_copy(Rooms)];
 mkjsAllSelect_copy([]) ->
	 [].

 mkjsAllSelectRm_copy([Room|Rows]) ->
	 [
 "

 $('#copyAllSelect"++Room++"').change(function(){

	 $('#copyAllInput"++Room++"').val($('#copyAllSelect"++Room++" option:selected').text());
	 ", jsAllSelectRows_copy(Room,Rows), "
 });

 "].

 jsAllSelectRows_copy(Room,[Row|Rows]) ->
	 [jsAllSelect_copy(Room,Row)|jsAllSelectRows_copy(Room,Rows)];
 jsAllSelectRows_copy(_Room,[]) ->
	 [].

 jsAllSelect_copy(Rm,[{Wk,_FQDN,_MacAddr,_Os}|Wks]) ->
	 case Wk of
		 "." ->	jsAllSelect_copy(Rm,Wks);
			_ ->
%			 Rm=string:sub_string(Wk,1,6),
			 [
 "
	 if(
		 ($('#copyAll",Rm,"check').prop('checked') && $('#",Wk,"check').prop('checked')) ||
		 (!$('#copyAll",Rm,"check').prop('checked') && 
			 (!$('#",Wk,"check').prop('checked') || $('#",Wk,"check').prop('checked')))
	   )
		 $('#copyfn_",Wk,"').val($('#copyAllInput"++Rm++"').val());
 "|jsAllSelect_copy(Rm,Wks)]
	 end;
 jsAllSelect_copy(_Room,[]) ->
	 [].
 %%

 mkjsSelect_copy([Room|Rooms]) ->
	 [mkjsSelectRm_copy(Room)|mkjsSelect_copy(Rooms)];
 mkjsSelect_copy([]) ->
	 [].

 mkjsSelectRm_copy([_Room|Rows]) ->
	jsSelectRows_copy(Rows).

 jsSelectRows_copy([Row|Rows]) ->
	 [jsSelect_copy(Row)|jsSelectRows_copy(Rows)];
 jsSelectRows_copy([]) ->
	 [].

 jsSelect_copy([{Wk,_FQDN,_MacAddr,_Os}|Wks]) ->
	 case Wk of
		 "." ->	jsSelect_copy(Wks);
			_ ->
			 [
 "

 $('#copyselect"++Wk++"').change(function(){
	 $('#copyfn_"++Wk++"').val($('#copyselect"++Wk++" option:selected').text());
 });

 "|jsSelect_copy(Wks)]
	 end;
 jsSelect_copy([]) ->
	 [].

 %%

 mkjsAllSelect_com([Room|Rooms]) ->
	 [mkjsAllSelectRm_com(Room)|mkjsAllSelect_com(Rooms)];
 mkjsAllSelect_com([]) ->
	 [].

 mkjsAllSelectRm_com([Room|Rows]) ->
	 [
 "

 $('#comAllSelect"++Room++"').change(function(){

	 $('#comAllInput"++Room++"').val($('#comAllSelect"++Room++" option:selected').text());
	 ", jsAllSelectRows_com(Room,Rows), "
 });

 "].

 jsAllSelectRows_com(Room,[Row|Rows]) ->
	 [jsAllSelect_com(Room,Row)|jsAllSelectRows_com(Room,Rows)];
 jsAllSelectRows_com(_Room,[]) ->
	 [].

 jsAllSelect_com(Rm,[{Wk,_FQDN,_MacAddr,_Os}|Wks]) ->
	 case Wk of
		 "." ->	jsAllSelect_com(Rm,Wks);
			_ ->
%			 Rm=string:sub_string(Wk,1,6),
			 [
 "
	 if(
		 ($('#comAll",Rm,"check').prop('checked') && $('#",Wk,"check').prop('checked')) ||
		 (!$('#comAll",Rm,"check').prop('checked') && 
			 (!$('#",Wk,"check').prop('checked') || $('#",Wk,"check').prop('checked')))
	   )
		 $('#comstr_",Wk,"').val($('#comAllInput"++Rm++"').val());
 "|jsAllSelect_com(Rm,Wks)]
	 end;
 jsAllSelect_com(_Room,[]) ->
	 [].
 
%%

 mkjsSelect_com([Room|Rooms]) ->
	 [mkjsSelectRm_com(Room)|mkjsSelect_com(Rooms)];
 mkjsSelect_com([]) ->
	 [].

 mkjsSelectRm_com([_Room|Rows]) ->
	jsSelectRows_com(Rows).

 jsSelectRows_com([Row|Rows]) ->
	 [jsSelect_com(Row)|jsSelectRows_com(Rows)];
 jsSelectRows_com([]) ->
	 [].

 jsSelect_com([{Wk,_FQDN,_MacAddr,_Os}|Wks]) ->
	 case Wk of
		 "." ->	jsSelect_com(Wks);
			_ ->
			 [
 "

 $('#comselect"++Wk++"').change(function(){
	 $('#comstr_"++Wk++"').val($('#comselect"++Wk++" option:selected').text());
 });

 "|jsSelect_com(Wks)]
	 end;
 jsSelect_com([]) ->
	 [].

%%

 mkjsSelectAllChk([Room|Rooms]) ->
	 [Rm|_]=Room,
	 [
"
 $('#selectAll"++Rm++"').click(function(){
     $('#"++Rm++" input:checkbox').each(function() {
         $(this).attr('checked','checked');
     });
 });

"|mkjsSelectAllChk(Rooms)];
 mkjsSelectAllChk([]) ->
	 [].

%%

 mkjsUnSelectAllChk([Room|Rooms]) ->
	 [Rm|_]=Room,
	 [
"
 $('#unselectAll"++Rm++"').click(function(){
     $('#"++Rm++" input:checkbox').each(function() {
         $(this).removeAttr('checked');
     });
 });

"|mkjsUnSelectAllChk(Rooms)];
 mkjsUnSelectAllChk([]) ->
	 [].

%%

 mkjsToggleAllChk([Room|Rooms]) ->
	 [Rm|_]=Room,
	 [
"
 $('#toggleAll"++Rm++"').click(function(){
     $('#"++Rm++" input:checkbox').each(function() {
         $(this).attr('checked',!$(this).attr('checked'));
     });
 });

"|mkjsToggleAllChk(Rooms)];
 mkjsToggleAllChk([]) ->
	 [].

%%

 mkAllRoomsComs(Coms) ->
	 mkARComs(?ROOMS,Coms).

 mkARComs([Room|Rooms],Coms) ->
	 [Rm|_]=Room,
	 ["<div id='",Rm,"_coms' class='room'>"++mkARComsComs(Rm,Coms)++"</div>"|mkARComs(Rooms,Coms)];
 mkARComs([],_Coms) ->
	 [].

 mkARComsComs(Rm,[{Com,ComText}|Coms]) ->
 ["

 <div class='fl'>
 <input id='",Com,"All",Rm,"check' type='checkbox' class='checkbox' /></a>
  <a href=# id='",Com,"All",Rm,"' class='button'/>",ComText,"</a>
 </div>
 <div class='brk'></div>

 "|mkARComsComs(Rm,Coms)];
 mkARComsComs(_Rm,[]) -> [].

%%

 mkAllRoomsComsInput(Com) ->
	 mkARComsInput(?ROOMS,Com).

 mkARComsInput([Room|Rooms],ComT) ->
	 {Com,ComText}=ComT,
	 [Rm|_]=Room,
	 ["

 <div id='",Rm,"_comsInput"++Com++"' class='room'>
	 "++mkARComsComsInput(Rm,ComT)++"
 </div>

 "|mkARComsInput(Rooms,{Com,ComText})];
 mkARComsInput([],_Com) ->
	[].

 mkARComsComsInput(Rm,{Com,ComText}) ->
 ["

 <div class='fl'>
 <input id='"++Com++"All"++Rm++"check' type='checkbox' class='checkbox' /></a>
  <a href=# id='"++Com++"All"++Rm++"' class='button' />",ComText,"</a>
 <div class='brk'></div>

 <select id='"++Com++"AllSelect"++Rm++"' class='fl'>
	 ",
		 case Com of
			 "copy" ->
				 selections(?APPS);
			 "com" ->
				 selections(?COMS)
		 end,
 "
 </select>
<br>
  <input id='"++Com++"AllInput"++Rm++"' type='text', name='"++Com++"AllInput' class='fl'/>

 </div>
 "].

%%

mkAllRoomsSelectUnselectToggleAll([Room|Rooms]) ->
	 [Rm|_]=Room,
	 ["
 <div class='brk'></div>

 <div id='",Rm,"_selunseltogall' class='room'>
<br>
	 "++mkselunseltogAll(Rm)++"
 </div>

 "|mkAllRoomsSelectUnselectToggleAll(Rooms)];
 mkAllRoomsSelectUnselectToggleAll([]) ->
	[].

 mkselunseltogAll(Rm) ->
 ["
  <a href=# id='selectAll"++Rm++"' class='button' />Select All</a><br>
  <a href=# id='unselectAll"++Rm++"' class='button' />UnSelect All</a><br>
  <a href=# id='toggleAll"++Rm++"' class='button' />Toggle All</a><br>
 "].

 %%

 mkRooms([Room|Rooms]) ->
	 [mkRoom(Room)|mkRooms(Rooms)];
 mkRooms([]) -> [].

 mkRoom([Room|Rows]) ->
	 [
 "

 <div id='",Room,"' class='room'>
 ",mkRoomRows(Rows,Room,1),"

 </div>

 "
	 ].

 mkRoomRows([Row|Rows],Rm,RowCnt) ->
	 [[
	  "
 <div id='",Rm,"_row_",integer_to_list(RowCnt),"'>",
	  divhc(Rm,Row,1),
	  "
 </div>
 <div class='brk'></div>
 <div>",
	  [divc(Wks) || Wks <- Row],
	  "
 </div>
 <div class='brk'></div>"
	 ]|mkRoomRows(Rows,Rm,RowCnt+1)];
 mkRoomRows([],_Rm,_RowCnt) ->
	 [].

 divhc(Rm,[{Wk,FQDN,MacAddr,_Os}|Wks],ColCnt) ->
	 [case Wk of
		 "." ->	["<div class='hltd'>.</div>"];
			_ ->
			 ["

<div id='",Wk,"_hltd' class='hltd ",Rm,"_col_",integer_to_list(ColCnt),"'>

<div id='",Wk,"status' class='status'>.</div>

<div class='wkchk'><input id='",Wk,"check' type='checkbox' class='checkbox' /></div></a><div class='wk'>",FQDN,"</div>

<div class='brk'></div>

<div id='",Wk,"macaddr' class='macaddr'>",MacAddr,"</div> <div id='",Wk,"dfstatus' class='dfstatus'>DF?</div>

</div>

"]
	  end|divhc(Rm,Wks,ColCnt+1)];
divhc(_Rm,[],_ColCnt) ->
	[].

divc({Wk,_FQDN,_MacAddr,_Os}) ->
	case Wk of
		"." ->	["<div class=\"ltd\">.</div>"];
		   _ ->
	["
<div id='"++Wk++"_ltd' class=\"ltd\">
<div id='"++Wk++"_ccell'>

<div class=\"lc\">
 <a href=# id='ping_",Wk,"' class='button' />P</a>
 <a href=# id='reboot_",Wk,"' class='button' />R</a>
 <a href=# id='shutdown_",Wk,"' class='button' />S</a>
 <a href=# id='wake_",Wk,"' class='button' />WOL</a>
 <a href=# id='dffreeze_",Wk,"' class='button' />DFF</a>
 <a href=# id='dfthaw_",Wk,"' class='button' />DFT</a>
 <a href=# id='dfstatus_",Wk,"' class='button' />DFS</a>
 <a href=# id='net_restart_",Wk,"' class='button' />ReS</a>
 <a href=# id='net_stop_",Wk,"' class='button' />StS</a>
 <a href=# id='loggedon_",Wk,"' class='button' />L</a>
 <a href=# id='",Wk,"_col' class='cols'>C</a>
</div>
<div class='brk'></div>
<div>
 <a href=# id='copy_",Wk,"' class='button' />Copy</a><br>

 <input id='copyfn_",Wk,"' type='text'/>

<select id='copyselect",Wk,"'>                                                                                                                                                                                              
    ",
       selections(?APPS),
"                                                                                                                                                                                                                                     
</select>

</div>

<div>

 <a href=# id='com_",Wk,"' class='button' />Com</a><br>

<input id='comstr_",Wk,"' type='text'/>

<select id='comselect",Wk,"'>                                                                                                                                                                                              
    ",
        selections(?COMS),
"                                                                                                                                                                                                                                     
</select>

</div>
</div>
</div>
"]
	end.

%

selections([Com|Coms]) ->
	[
"
<option value=\""++Com++"\">"++Com++"</option>
"|selections(Coms)];
selections([]) ->
[].
	
%

mkcomButtons([Room|Rooms]) ->
	[comButtonsRm(Room)|mkcomButtons(Rooms)];
mkcomButtons([]) ->
	[].

comButtonsRm([Room|Rows]) ->
    comButtonsRows(Rows,Room,1).

comButtonsRows([Row|Rows],Rm,RowCnt) ->
	[comButtons(Row,Rm,RowCnt,1)|comButtonsRows(Rows,Rm,RowCnt+1)];
comButtonsRows([],_Rm,_RowCnt) ->
	[].

comButtons([{Wk,FQDN,MacAddr,_Os}|Wks],Rm,RowCnt,ColCnt) ->
	case Wk of
		"." -> comButtons(Wks,Rm,RowCnt,ColCnt+1);
		_ ->
	["

    $('#",Wk,"_col').click(function(){
        $('.",Rm,"_col_",integer_to_list(ColCnt)," input:checkbox').each(function() {
           $(this).attr('checked',!$(this).attr('checked'));
       });
	});

    $('#",Wk,"status').click(function(){
        $('#",Rm,"_row_",integer_to_list(RowCnt)," input:checkbox').each(function() {
           $(this).attr('checked',!$(this).attr('checked'));
       });
	});

	$('#reboot_",Wk,"').click(function(){
        r=false;
        if (rall==false)
            r=confirm('Reboot ",Wk,"?');
        if (r==true || rall==true){
   		    send('",FQDN,":reboot:0');
		    message(true,'Rebooting ",Wk,"...')
        } else
		    message(true,'Reboot of ",Wk," aborted...')
	});

	$('#shutdown_",Wk,"').click(function(){
        r=false;
        if (rall==false)
            r=confirm('Shutdown ",Wk,"?');
        if (r==true || rall==true){
		    send('",FQDN,":shutdown:0');
		    message(true,'Shutting down ",Wk,"...');
        } else
		    message(true,'Shutdown of ",Wk," aborted...')
	});

	$('#wake_",Wk,"').click(function(){
		send('",FQDN,":wol:",MacAddr,"');
		message(true,'Waking ",Wk,"...')
	});

	$('#ping_",Wk,"').click(function(){
		send('",FQDN,":ping:0');
		message(true,'Pinging ",Wk,"...');
	});

	$('#net_restart_",Wk,"').click(function(){
		send('",FQDN,":net_restart:0');
		message(true,'Restarting win service on ",Wk,"...')
	});

	$('#net_stop_",Wk,"').click(function(){
		send('",FQDN,":net_stop:0');
		message(true,'Stopping win service on ",Wk,"...')
	});

	$('#dffreeze_",Wk,"').click(function(){
        r=false;
        if (rall==false)
            r=confirm('Freeze ",Wk,"?');
        if (r==true || rall==true){
   		    send('",FQDN,":dffreeze:0');
		    message(true,'Freezing ",Wk,"...')
            $('#",Wk,"status').html('.');
        } else
		    message(true,'Freeze of ",Wk," aborted...')
	});

	$('#dfthaw_",Wk,"').click(function(){
        r=false;
        if (rall==false)
            r=confirm('Thaw ",Wk,"?');
        if (r==true || rall==true){
   		    send('",FQDN,":dfthaw:0');
		    message(true,'Thawing ",Wk,"...')
            $('#",Wk,"status').html('.');
        } else
		    message(true,'Thaw of ",Wk," aborted...')
	});

	$('#dfstatus_",Wk,"').click(function(){
		send('",FQDN,":dfstatus:0');
		message(true,'DF Status sent ",Wk,"...')
	});

	$('#loggedon_",Wk,"').click(function(){
		send('",FQDN,":loggedon:0');
		message(true,'loggedon sent ",Wk,"...')
	});

	$('#copy_",Wk,"').click(function(){
        if($('#copyfn_",Wk,"').val().length){
		    send('",FQDN,":copy:' + $('#copyfn_",Wk,"').val());
		    message(true,'Copy sent ",Wk,"...')
        } else {
            $('#copyfn_",Wk,"').val('!');
		    message(true,'Copy file name blank! ",Wk,"...')
        }
	});

	$('#com_",Wk,"').click(function(){
        if($('#comstr_",Wk,"').val().length){
		    send('",FQDN,":com:' + $('#comstr_",Wk,"').val());
		    message(true,'Command sent ",Wk,"...')
        } else {
            $('#comstr_",Wk,"').val('!');
		    message(true,'Command is blank! ",Wk,"...')
        }
	});

    "|comButtons(Wks,Rm,RowCnt,ColCnt+1)]
	end;
comButtons([],_Rm,_RowCnt,_ColCnt) ->
	[].
%%

mkjsComAll([Room|Rooms],Com) ->
	[mkjsComAllRm(Room,Com)|mkjsComAll(Rooms,Com)];
mkjsComAll([],_Com) ->
	[].

mkjsComAllRm([Rm|Rows],Com) ->
	[
"

function ",Com,"All"++Rm++"(){
", mkjsComAllRows(Rows,Rm,Com), "
    rall=false;
}

"].

mkjsComAllRows([Row|Rows],Rm,Com) ->
	[mkjsComAllRow(Row,Rm,Com)|mkjsComAllRows(Rows,Rm,Com)];
mkjsComAllRows([],_Rm,_Com) ->
    [].

mkjsComAllRow([{Wk,_FQDN,_MacAddr,_Os}|Wks],Rm,Com) ->
	case Wk of
		"." ->	mkjsComAllRow(Wks,Rm,Com);
		   _ ->
[
case Com of
	"copy" ->
["
    if(
        ($('#",Com,"All",Rm,"check').prop('checked') && $('#",Wk,"check').prop('checked')) ||
        (!$('#",Com,"All",Rm,"check').prop('checked') && 
            (!$('#",Wk,"check').prop('checked') || $('#",Wk,"check').prop('checked')))
      ){
	    $('#copyfn_"++Wk++"').val($('#copyAllInput"++Rm++"').val());
        $('#copy_",Wk,"').click();
    }
"];
	_  -> 
["
    if(
        ($('#",Com,"All",Rm,"check').prop('checked') && $('#",Wk,"check').prop('checked')) ||
        (!$('#",Com,"All",Rm,"check').prop('checked') && 
            (!$('#",Wk,"check').prop('checked') || $('#",Wk,"check').prop('checked')))
      )
        $('#",Com,"_",Wk,"').click();
"]
end
|mkjsComAllRow(Wks,Rm,Com)]
	end;
mkjsComAllRow([],_Rm,_Com) ->
	[].

%%

init2([Room|Rooms],Ref_cons_time) ->	
	[init2_rm(Room,Ref_cons_time)|init2(Rooms,Ref_cons_time)];
init2([],_) ->
    [].

init2_rm([Rm|_],Ref_cons_time) ->[
"
                     interval_"++Rm++"_ref_cons=setInterval(refresh_cons_"++Rm++","++integer_to_list(Ref_cons_time)++");

"].

%%

get_rms_keys([Room|Rooms],Key) ->
	[Rm|_]=Room,
	[{Rm,Key}|get_rms_keys(Rooms,Key+1)];
get_rms_keys([],_) ->
	[].

rms_keys([{Rm,_}|Rms],Rms_ks) ->
	[
"
    $('#"++Rm++"toggle').keydown(function(event) {
",
loop_rms_keys(Rms_ks),
"
    });

"|rms_keys(Rms,Rms_ks)];
rms_keys([],_) ->
	[].

%

loop_rms_keys([Rm|Rms]) ->
	[loop_rm_keys(Rm)|loop_rms_keys(Rms)];
loop_rms_keys([]) ->
	[].

loop_rm_keys({Rm,Key}) ->
"
        if (event.which == "++integer_to_list(Key)++"){
            event.preventDefault();
            $('#"++Rm++"toggle').click();
        }
".

%

chk_dupe_usersa(Rooms) ->
    [
"
function  chk_dupe_users(){
        tot_cnt=0;
",
chk_dupe_users_rms(Rooms),
"
}
"].

chk_dupe_users_rms([Room|Rooms]) ->

[jschkduRma(Room)|chk_dupe_users_rms(Rooms)];
chk_dupe_users_rms([]) ->
	[].

jschkduRma([Rm|_Rows]) ->
	[
"
    chk_dupe_users_"++Rm++"();

"].

%

chk_dupe_users([Room|Rooms]) ->
[jschkduRm(Room)|chk_dupe_users(Rooms)];
chk_dupe_users([]) ->
	[].

jschkduRm([Rm|Rows]) ->
	[
"

function chk_dupe_users_"++Rm++"(){
    var dupe_"++Rm++"=[];

    var hash_"++Rm++" = [];

	var "++Rm++"cnt=0;
    

", jschkduRows(Rows,Rm), "

    for (var key in hash_"++Rm++"){
        if (hash_"++Rm++".hasOwnProperty(key) && hash_"++Rm++"[key].length > 1)
            $('#msgdup').html(key+':['+hash_"++Rm++"[key]+']<br>'+$('#msgdup').html())
    }

    $('#"++Rm++"toggle').html('['+(("++Rm++"cnt>0)?"++Rm++"cnt:0).toString()+']-"++Rm++"');

}

"].
jschkduRows([Row|Rows],Rm) ->
	[jschkduRow(Row,Rm)|jschkduRows(Rows,Rm)];
jschkduRows([],_Rm) ->
    [].

jschkduRow([{Wk,_FQDN,_MacAddr,_Os}|Wks],Rm) ->
	case Wk of
		"." ->	jschkduRow(Wks,Rm);
		   _ ->
["

    if ($('#"++Wk++"status').html()!='.'){
        dupe_"++Rm++".push($('#"++Wk++"status').html().toLowerCase());
        if (typeof hash_"++Rm++"[dupe_"++Rm++"[dupe_"++Rm++".length-1]] === 'undefined')
            hash_"++Rm++"[dupe_"++Rm++"[dupe_"++Rm++".length-1]] = [];
        hash_"++Rm++"[dupe_"++Rm++"[dupe_"++Rm++".length-1]].push('"++Wk++"');
        "++Rm++"cnt++;
        tot_cnt++;
        $('#rooms_title').html('['+tot_cnt.toString()+']-'+'Rooms:');
    }
"
|jschkduRow(Wks,Rm)]
	end;
jschkduRow([],_Rm) ->
	[].

%

switcher([Room|Rooms]) ->
	[switcher_rm(Room)|switcher(Rooms)];
switcher([]) ->
	[].

switcher_rm([Rm|_Rows]) ->
	[
"
<a href=# id='"++Rm++"toggle' class='button1' />[0]-"++Rm++"</a>
"].

%

refresh_cons([Room|Rooms]) ->
	[jsrefcons_rm(Room)|refresh_cons(Rooms)];
refresh_cons([]) ->
	[].

jsrefcons_rm([Rm|Rows]) ->
	[
"

function refresh_cons_",Rm,"(){
",
	 jsrefcons_rows(Rows,Rm),
"
}
"].

jsrefcons_rows([Row|Rows],Rm) ->
	[jsrefcons_row(Row,Rm)|jsrefcons_rows(Rows,Rm)];
jsrefcons_rows([],_Rm) ->
    [].

jsrefcons_row([{Wk,_FQDN,_MacAddr,_Os}|Wks],Rm) ->
	case Wk of
		"." ->	jsrefcons_row(Wks,Rm);
		   _ ->
["

		$('#",Wk,"_hltd').css('background-color','#000');
		$('#",Wk,"_ltd').css('background-color','#000');
		$('#",Wk,"dfstatus').css('color','cyan');
		$('#",Wk,"dfstatus').css('background-color','#006666');
		$('#",Wk,"status').css('color','red');
		$('#",Wk,"status').css('background-color','#550000');
        $('#",Wk,"status').html('.');

"
|jsrefcons_row(Wks,Rm)]
	end;
jsrefcons_row([],_Rm) ->
	[].
