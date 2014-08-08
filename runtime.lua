local Guard = require "guard"
local remoteIp = ngx.var.remote_addr
local headers = ngx.req.get_headers()
local ip = Guard:getRealIp(remoteIp,headers)
local reqUri = ngx.var.request_uri
local uri = ngx.var.uri
local address = ''
local method =ngx.req.get_method
--判断是某种url匹配模式
if _Conf.uriMode then
	address = uri
elseif _Conf.requestUriMode then
	address = reqUri
end	


--获取验证码
if ngx.re.match(uri,"/get-captcha.jpg$","i") then
	Guard:getCaptcha()

--验证验证码
elseif ngx.re.match(uri,"/verify-captcha.jpg$","i") then
	Guard:verifyCaptcha(ip)

--过滤请求
else
	--定时检查连接数
	if _Conf.autoEnableIsOn then
		ngx.timer.at(0,Guard.autoSwitch)
	end
		
	--白名单模块
	if not Guard:ipInWhiteList(ip) then
		--黑名单模块
		Guard:blackListModules(ip,reqUri)

		--限制请求速率模块
		if _Conf.limitReqModulesIsOn then --limitReq模块是否开启
			Guard:debug("[limitReqModules] limitReqModules is on.",ip,reqUri)
			Guard:limitReqModules(ip,reqUri,address)
		end

		--302转向模块
		local redirectOn = _Conf.dict_captcha:get("redirectOn")
		if redirectOn == 1 then --判断转向模块是否开启
			Guard:debug("[redirectModules] redirectModules is on.",ip,reqUri)
			Guard:redirectModules(ip,reqUri,address)
		end	

		--js跳转模块
		local jsOn = _Conf.dict_captcha:get("jsOn")
		if jsOn == 1 then --判断js跳转模块是否开启
			Guard:debug("[JsJumpModules] JsJumpModules is on.",ip,reqUri)
			Guard:JsJumpModules(ip,reqUri,address)
		end

		--cookie验证模块
		local cookieOn = _Conf.dict_captcha:get("cookieOn")
		if cookieOn == 1 then --判断是否开启cookie模块
			Guard:debug("[cookieModules] cookieModules is on.",ip,reqUri)
			Guard:cookieModules(ip,reqUri,address)
		end
		--url参数验证模块
		local uriOn =_Conf.dict_captcha:get("urifilter")
		if uriOn == 1 then
        	        Guard:debug("[uriFilterModules] uriFilterModules is on.",ip,reqUri)
                	Guard:uriFilterModule(ip,reqUri)

		end
		--header-test
		local header=1
		if header then
			ngx.req.read_body()
			local args, err = ngx.req.get_post_args()
			ngx.header.content_type = "text/html"
			if not args then
		                ngx.say("failed to get post args: ", err)
                		return
		        end
		        for key, val in pairs(args) do
                		if type(val) == "table" then
			                ngx.say(key, ": ", table.concat(val, ", "))
					ngx.exit(403)
	                	else
					if ngx.re.match(val,'script','i') then
						ngx.exit(403)
					else
					        ngx.say(key, ": ", val)
						ngx.exit(200)
					end
                		end
		        end
		end
		
			
	end	
end

