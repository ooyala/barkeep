//
// RelWare's "Cookie" manager jQuery plugin definition
// © 2010 - RelWare - www.relware.com - All rights reserved
//

(function($) 
{

	////////////////////////////////////
	//
	// PUBLIC VARIABLES AND FUNCTIONS
	//
	////////////////////////////////////

	// Usage: 	
	//      $.cookies() - no params will return an array of all cookies
	//      $.cookies(name) - single param will return the cookie for the given value
	//      $.cookies(name, value) - two params will set the cookie for the name with the given value with no expiration
	//      $.cookies(name, value, expiration) - three params will set the expiration for the cookie 
	//
	// Parameters:
	//      cookieName - (string) the name of the cookie being requested (optional)
	//      cookieValue - (string) the value to be set for the named cookie (optional)
	//      expiration - (object) either a date object, or an object with .duration and .units properties (preferred)
	
	if (!$.cookies)
	{
		$.cookies = function(cookieName, cookieValue, expiration)
		{
			if (arguments.length == 0)
			{// return all cookies in an array
				var cookies = {};

				var cookieList = document.cookie.split(";");

				for (var i=0; i < cookieList.length; i++)
				{
					var cookieEntry = cookieList[i];
					cookies[cookieEntry.substr(0,cookieEntry.indexOf("=")).replace(/^\s+|\s+$/g,"")] = decodeURIComponent(cookieEntry.substr(cookieEntry.indexOf("=")+1));
				}
				
				return cookies;
			}
			else if (arguments.length == 1)
			{// return a specific cookie
				return $.cookies()[cookieName];
			}
			else
			{// set a specific cookie with (or without) an expiration
				var setString = cookieName + "=" + encodeURIComponent(cookieValue);
				if (typeof expiration == 'object')
				{
					if ( (typeof expiration.duration == 'number') && (typeof expiration.units == 'string') )
					{
						var expDate = new Date();
						
						switch (expiration.units)
						{
							case 'minute':
							case 'minutes':
								expDate.setMinutes(expDate.getMinutes() + expiration.duration);
								break;
							case 'hour':
							case 'hours':
								expDate.setHours(expDate.getHours() + expiration.duration);
								break;
							case 'day':
							case 'days':
								expDate.setDate(expDate.getDate() + expiration.duration);
								break;
							case 'week':
							case 'weeks':
								expDate.setDate(expDate.getDate() + (expiration.duration * 7));
								break;
							case 'month':
							case 'months':
								expDate.setMonth(expDate.getMonth() + expiration.duration);
								break;
							case 'year':
							case 'years':
								expDate.setYear(expDate.getYear() + expiration.duration);
								break;
						}

				 		setString += "; expires=" + expDate.toUTCString();
					}
					else if (typeof expiration.toUTCString == 'function')
					{
				 		setString += "; expires=" + expiration.toUTCString();
				 	}
				}
				document.cookie = setString;
			}
		};
	}



})(jQuery);
