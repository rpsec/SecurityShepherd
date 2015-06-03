<%@ page contentType="text/html; charset=iso-8859-1" language="java" import="java.sql.*,java.io.*,java.net.*,org.owasp.esapi.ESAPI, org.owasp.esapi.Encoder, dbProcs.*, utils.*, servlets.admin.userManagement.GetPlayersByClass" errorPage="" %>

<%
	ShepherdLogManager.logEvent(request.getRemoteAddr(), request.getHeader("X-Forwarded-For"), "DEBUG: changeUserPassword.jsp *************************");

/**
 * This file is part of the Security Shepherd Project.
 * 
 * The Security Shepherd project is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.<br/>
 * 
 * The Security Shepherd project is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.<br/>
 * 
 * You should have received a copy of the GNU General Public License
 * along with the Security Shepherd project.  If not, see <http://www.gnu.org/licenses/>. 
 * 
 * @author Mark Denihan
 */
 
if (request.getSession() != null)
{
HttpSession ses = request.getSession();
Getter get = new Getter();
//Getting CSRF Token from client
Cookie tokenCookie = null;
try
{
	tokenCookie = Validate.getToken(request.getCookies());
}
catch(Exception htmlE)
{
	ShepherdLogManager.logEvent(request.getRemoteAddr(), request.getHeader("X-Forwarded-For"), "DEBUG(upgradePlayers.jsp): tokenCookie Error:" + htmlE.toString());
}
// validateAdminSession ensures a valid session, and valid administrator credentials
// Also, if tokenCookie != null, then the page is good to continue loading
// Token is now validated when accessing admin pages to stop attackers causing other users to tigger logs of access attempts
Object tokenParmeter = request.getParameter("csrfToken");
if(Validate.validateAdminSession(ses, tokenCookie, tokenParmeter))
{

//Logging Username
ShepherdLogManager.logEvent(request.getRemoteAddr(), request.getHeader("X-Forwarded-For"), "Accessed by: " + ses.getAttribute("userName").toString(), ses.getAttribute("userName"));
// Getting Session Variables
//This encoder should escape all output to prevent XSS attacks. This should be performed everywhere for safety
Encoder encoder = ESAPI.encoder();
String csrfToken = encoder.encodeForHTMLAttribute(tokenCookie.getValue());
String userName = encoder.encodeForHTML(ses.getAttribute("userName").toString());
String userRole = encoder.encodeForHTML(ses.getAttribute("userRole").toString());
String userId = encoder.encodeForHTML(ses.getAttribute("userStamp").toString());
String ApplicationRoot = getServletContext().getRealPath("");
boolean showClasses = false;

ResultSet classList = Getter.getClassInfo(ApplicationRoot);
try
{
	showClasses = classList.next();
}
catch(SQLException e)
{
	ShepherdLogManager.logEvent(request.getRemoteAddr(), request.getHeader("X-Forwarded-For"), "Could not open classList: " + e.toString());
	showClasses = false;
}
%>
	<div id="formDiv" class="post">
		<h1 class="title">Change Player Password</h1>
		<div id="resetPasswordDiv" class="entry">
			<form id="theForm" action="javascript:;">
				<p>You can use this function to update a users password. This password will be temporary, and they will be forced to change it upon sign in.</p>
				<div id="badData"></div>
				<input type="hidden" id="csrfToken" value="<%=csrfToken%>"/>
				<table align="center">
					<tr>
						<td colspan="2">
							<p>Pick the class of the player you wish to modify</p>
							<center>
							<select id="selectClass" style="width: 300px;">
								<option value="">Unassigned Players</option>
								<%
								if(showClasses)
								{
									try
									{
										do
										{
											String classId = encoder.encodeForHTML(classList.getString(1));
											String classYearName = encoder.encodeForHTML(classList.getString(3)) + " " + encoder.encodeForHTML(classList.getString(2));
											%>
											<option value="<%=classId%>"><%=classYearName%></option>
											<%
										}
										while(classList.next());
										classList.first();
									}
									catch(SQLException e)
									{
										ShepherdLogManager.logEvent(request.getRemoteAddr(), request.getHeader("X-Forwarded-For"), "Error occured when manipulating classList: " + e.toString());
										showClasses = false;
									}
								}
								%>
							</select>
							</center>
						</td>
					</tr>
					<tr>
						<td colspan="2">
							<p>Select the player that you want to assign here</p>
							<div id="playerSelect">	
								<center>
									<select id='playerId' style='width: 300px;'>
										<%= GetPlayersByClass.playersInOptionTags(Getter.getPlayersByClass(ApplicationRoot, null)) %>
									</select>
								</center>
								<br>
							</div>
						</td>
					</tr>
					<tr><td>New Password:</td><td><input type="password" style='width: 300px' id="newPassword"/></td></tr>
					<tr><td colspan="2" align="center">
						<input type="submit" id="submitButton" value="Update Player Password"/>
					</td></tr>
				</table>
			</form>
		</div>
		<br>
				<div id="loadingDiv" style="display:none;" class="menuButton">Loading...</div>
				<div id="resultDiv" style="display:none;" class="informationBox"></div>
				<div id="badData"></div>
	</div>
	<script>
	$("#selectClass").change(function () {
		var theCsrfToken = $('#csrfToken').val();
		var ajaxCall = $.ajax({
			type: "POST",
			url: "getPlayersByClass",
			data: {
				classId: $("#selectClass option:selected").val(),
				csrfToken: theCsrfToken
			},
			async: false
		});
		if(ajaxCall.status == 200)
		{
			$("#playerSelect").hide("fast", function(){
				if(ajaxCall.responseText == '')
				{
					$("#playerSelect").html("<p><font color='red'>Sorry, but there are no players in this class</font></p>");
				}
				else if(ajaxCall.responseText == 'fail')
				{
					$("#playerSelect").html("<p><font color='red'>Sorry, but an error occured! Please try again!</font></p>");
				}
				else
				{
					$("#playerSelect").html("<center><select id='playerId' style='width: 300px'>" + ajaxCall.responseText + "</select><br></center>");
				}
				$("#playerSelect").show("slow");
			});
		}
		else
		{
			$("#badData").html("<p> Sorry but there was an error: " + ajaxCall.status + " " + ajaxCall.statusText + "</p>");
		}
	});
	
	$("#theForm").submit(function(){
		//Get Data
		var theCsrfToken = $('#csrfToken').val();
		var theNewPassword = $('#newPassword').val();
		var thePlayers = $("#playerId").val();
		//Validation
		if (thePlayers == null)
		{
			$('#badData').html("<p><strong><font color='red'>Please select a player to update.</font></strong></p>");
		}
		else if (theNewPassword.length < 8)
		{
			$('#badData').html("<p><strong><font color='red'>Password must be at least 8 characters long.</font></strong></p>");
		}
		else
		{
			//Hide&Show Stuff
			$("#loadingDiv").show("fast");
			$("#badData").hide("fast");
			$("#resultDiv").hide("fast");
			$("#resetPasswordDiv").slideUp("fast", function(){
				//The Ajax Operation
				var ajaxCall = $.ajax({
					type: "POST",
					url: "changeUserPassword",
					data: {
						player: thePlayers,
						password: theNewPassword,
						csrfToken: theCsrfToken
					},
					async: false
				});
				$("#loadingDiv").hide("fast", function(){
					if(ajaxCall.status == 200)
					{
						//Now output Result Div and Show
						$("#resultDiv").html(ajaxCall.responseText);
						$("#resultDiv").show("fast");
					}
					else
					{
						$("#badData").html("<div id='errorAlert'><p> Sorry but there was an error: " + ajaxCall.status + " " + ajaxCall.statusText + "</p></div>");
						$("#badData").show("slow");
					}
					$("#resetPasswordDiv").slideDown("slow");
				});
			});
		}
	});
	</script>
	<% if(Analytics.googleAnalyticsOn) { %><%= Analytics.googleAnalyticsScript %><% } %>
	<%
}
else
{
response.sendRedirect("../../loggedOutSheep.html");
}
}
else
{
response.sendRedirect("../../loggedOutSheep.html");
}
%>