crypto= require 'crypto'
mp_xml= require './xml'

DEFAULT_OPTIONS =
	tokenProp: 'wx_token'
	dataProp: 'body'
	session: true
# 加密/校验流程如下：
# 1. 将token、timestamp、nonce三个参数进行字典序排序
# 2. 将三个参数字符串拼接成一个字符串进行sha1加密
# 3. 开发者获得加密后的字符串可与signature对比，标识该请求来源于微信
calcSig= (token, timestamp, nonce)->
	s= [token, timestamp, nonce].sort()
								.join('')
	crypto.createHash 'sha1'
		  .update s
		  .digest 'hex'
# Check signature
checkSig= (token, query)->
	unless query then return false
	return query.signature is calcSig token, query.timestamp, query.nonce

# 合并数组
defaults= (a, b)-> for k in b when i not in a then a[k]= b[k]

# New Wechat MP instance, handle default configurations
# Options:
#    `token`      - wechat token
#  `tokenProp`  - will try find token from this property of `req`
Wechat= (options)->
	unless @ instanceof Wechat then return new Wechat options
	if 'string' is typeof options then options= {token: options}
	@options= options or {}
	defaults @options, DEFAULT_OPTIONS

#To parse wechat xml requests to webot Info realy-to-use Object.
#@param {object|String} options/token
Wechat::start= Wechat::parser= bodyParser= (opts)->
	if 'string' is typeof opts then opts= {token: opts}
	opts= opts or {}
	defaults opts, @options

	self= @
	tokenProp= opts.tokenProp
	dataProp= opts.tokenProp
	generateSid= undefined
	if opts.session isnt false then generateSid= (data)-> ['wx', data.sp, data.uid].join '.'
	return (req, res, next)->
		# use a special property to demine whether this is a wechat message
		if req[dataProp] and req[dataProp].sp then return next()
		token= req[dataProp] or opts.token
		unless checkSig(token, req.query) then return Wechat.block(res)
		if req.method is 'GET' then return res.end(req.query.echostr)
		if req.method is 'HEAD' then return res.end()
		Wechat.parse req, (err, data)->
			if err
				res.statusCode= 400
				return res.end()
			req[dataProp]= data
			if generateSid
				sid= generateSid(data)
				# always return the same sessionID for a given service_provider+subscriber
				propdef=
					get: -> return sid
					set: ->
				Object.defineProperty req, 'sessionID', propdef
				Object.defineProperty req, 'sessionId', propdef
			next()

# to build reply object as xml string
Wechat::end= Wechat::responder= responder= ->
	return (req, res, next)->
		res.setHeader 'Content-Type', 'application/xml'
		res.end Wechat.dump(Wechat.ensure(res.body, req.body))

# Ensure reply string is a valid reply object,
# get data from request message
Wechat.ensure= (reply, data)->
	reply= reply or {content: ''}
	data= data or {}
	if 'string' is typeof reply then reply= {content: reply, msgType: 'text'}
	# fillup with defaults values
	reply.uid= reply.uid or data.uid
	reply.sp= reply.sp or data.sp
	# msgType is always lowercase
	reply.msgType= (reply.msgType or reply.type or 'text').toLowerCase()
	reply.createTime= reply.createTime or new Date()
	return reply

Wechat.parse= (req, callback)->
	chunks= []
	req.on 'data', (data)-> chunks.push data
	req.on 'end', ()->
		req.rawBody= Buffer.concat chunks
						   .toString()
		try
			data= Wechat.load req.rawBody
			callback null, data
		catch e
			return callback(e)

# Check signature			
Wechat.checkSignature= checkSig

# parse xml string
Wechat.load= mp_xml.parse

# dump reply as xml string
# if content in reply is empty should return empty string as response body
# see: https://mp.weixin.qq.com/cgi-bin/announce?action=getannouncement&key=1413446944&version=15&lang=zh_CN
Wechat.dump= (reply)->
	if reply.content is '' then return ''
	return mp_xml.build reply

module.exports= Wechat