lodash_tmpl= require 'lodash/string/template'
xmllite= require 'node-xml-lite'

propMap=
	FromUserName: 'uid'
	ToUserName: 'sp' # as 'service provider'
	CreateTime: 'createTime'
	MsgId: 'id'
	MsgType: 'type'
	Content: 'text'

paramMap=
	Location_X: 'lat'
	Location_Y: 'lng'
	# 上报地理位置事件 Event == LOCATION
	Latitude: 'lat'
	Longitude: 'lng'

# convert weixin props into more human readable names
# original, pmap, mmap
# xml,      propMap, paramMap
readable= (original, pmap, mmap)->
	param= {}
	data=
		raw: original
		param: param
	for key, val in original
		if key in pmap then data[pmap[key]]= val
		else if key in mmap then param[mmap[key]]= val
		else
			# convert first letter into lowcase
			# 其他参数都是将首字母转为小写
			key= key[0].toLowerCase()+ key.slice(1)
			if key is 'recognition' then data.text= val
			param[key]= val
	data.createTime= new Date(parseInt(data.createTime, 10)* 1000)
	# for compatibility
	data.created= data.createTime
	return data

flattern= (tree)->
	ret= {}
	if tree.childs?
		tree.childs.forEach (item)->
			unless item.name?
				ret= item
				return false
			value= flattern item
			if item.name of ret then ret[item.name]= [ret[item.name], value]
			ret[item.name]= value
	return ret

parseXml= (b, options)->
	options= options or {}
	pmap= options.propMap or propMap
	mmap= options.paramMap or paramMap
	tree= xmllite.parseString b
	# parsed data:
	# { name: 'xml', 
	#	childs: [{name: 'ToUserName', childs: [Object]},{...}]
	# }
	xml= flattern tree
	# flatterned data:
	# { ToUserName: 'gh_d233b965e39f', 
	#   FromUserName: 'oQZrDjouco9hrooRLzsNgBqFEnzY',
	#   ....
	# }	
	return readable xml, pmap, mmap

# construct necessary xml
renderXml= lodash_tmpl [
	'<xml>',
	'<ToUserName><![CDATA[<%- uid %>]]></ToUserName>',
	'<FromUserName><![CDATA[<%- sp %>]]></FromUserName>',
	'<CreateTime><%= Math.floor(createTime.valueOf() / 1000) %></CreateTime>',
	'<MsgType><![CDATA[<%= msgType %>]]></MsgType>',
	'<% if (msgType === "transfer_customer_service" && kfAccount) { %>',
	'<TransInfo>',
	'<KfAccount><%- kfAccount %></KfAccount>',
	'</TransInfo>',
	'<% } %>',
	'<% if (msgType === "news") { %>',
	'<ArticleCount><%=content.length%></ArticleCount>',
	'<Articles>',
	'<% content.forEach(function(item){ %>',
	'<item>',
	'<Title><![CDATA[<%=item.title%>]]></Title>',
	'<Description><![CDATA[<%=item.description%>]]></Description>',
	'<PicUrl><![CDATA[<%=item.picUrl || item.picurl || item.pic %>]]></PicUrl>',
	'<Url><![CDATA[<%=item.url%>]]></Url>',
	'</item>',
	'<% }) %>',
	'</Articles>',
	'<% } else if (msgType === "music") { %>',
	'<Music>',
	'<Title><![CDATA[<%=content.title%>]]></Title>',
	'<Description><![CDATA[<%=content.description%>]]></Description>',
	'<MusicUrl><![CDATA[<%=content.musicUrl || content.url %>]]></MusicUrl>',
	'<HQMusicUrl><![CDATA[<%=content.hqMusicUrl || content.hqUrl %>]]></HQMusicUrl>',
	'</Music>',
	'<% } else if (msgType === "voice") { %>',
	'<Voice>',
	'<MediaId><![CDATA[<%=content.mediaId%>]]></MediaId>',
	'</Voice>',
	'<% } else if (msgType === "image") { %>',
	'<Image>',
	'<MediaId><![CDATA[<%-content.mediaId%>]]></MediaId>',
	'</Image>',
	'<% } else if (msgType === "video") { %>',
	'<Video>',
	'<Title><![CDATA[<%=content.title%>]]></Title>',
	'<Description><![CDATA[<%=content.description%>]]></Description>',
	'<MediaId><![CDATA[<%=content.mediaId%>]]></MediaId>',
	'<ThumbMediaId><![CDATA[<%=content.thumbMediaId%>]]></ThumbMediaId>',
	'</Video>',
	'<% } else { %>',
	'<Content><![CDATA[<%=content%>]]></Content>',
	'<% } %>',
	'</xml>'
].join('')

module.exports=
	parse: parseXml
	build: renderXml