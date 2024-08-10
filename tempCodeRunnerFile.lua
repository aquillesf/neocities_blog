load_js("https://cdn.jsdelivr.net/npm/marked/marked.min.js")
load_js("https://cdnjs.cloudflare.com/ajax/libs/dompurify/3.0.6/purify.min.js")

var HtmlChanLib = (function() {
	function findHtmlChan(postBodyInnerHTML) {
		let begin = postBodyInnerHTML.indexOf("@@@@@BEGIN HTML CHAN@@@@@")
		if(begin < 0)
			return {
				valid: false,
				begin: 0,
				end: 0
			}

		let end = postBodyInnerHTML.indexOf("@@@@@END HTML CHAN@@@@@", begin + 1)
		if(end < 0)
			return {
				valid: false,
				begin: 0,
				end: 0
			}
		
		return {
			begin: begin,
			end: end,
			valid: true
		}
	}

	async function compressGZIP(data) {
		const cs = new CompressionStream('gzip');
		const writer = cs.writable.getWriter();
		writer.write(data)
		writer.close();
		return await new Response(cs.readable).arrayBuffer().then(function(result) {
			return new Uint8Array(result);
		})
	}

	async function decompressGZIP(byteArray) {
		const ds = new DecompressionStream('gzip');
		const writer = ds.writable.getWriter();
		writer.write(byteArray);
		writer.close();
		return await new Response(ds.readable).arrayBuffer().then(function(result) {
			return new Uint8Array(result);
		})
	}

	function fromBase64(str) {
		let byteChar = atob(str)
		let buffer = new Array(byteChar.length)
		for(var i = 0; i < byteChar.length; i++) {
			buffer[i] = byteChar.charCodeAt(i)
		}
		return new Uint8Array(buffer)
	}

	async function processHtmlChan(innerHTML) {
		let content_fix = innerHTML.trim();
		let content_compressed = fromBase64(content_fix)
		let content = await decompressGZIP(content_compressed)
		let cfg = {
			USE_PROFILE: {
				html: true
			},
			ALLOWED_TAGS: [
				'a',
				'b',
				'i',
				'ul',
				'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
				'br',
				'ul',
				'li',
				'table',
				'tr', 'td',
				'hr',
				'code',
				'pre',
				'del',
				'em',
				'meter',
				'progress',
				'q',
				's',
				'strong',
				'sub',
				'sup',
				'time',
				'u',
				'small',
				'samp',
				'img',
				'p',
				'span'
			],
			FORBID_ATTR: [
				'style',
				'onclick',
				'onchange',
				'onmouseover',
				'onfocus',
				'onload',
				'onerror'
			]
		}

		let sanitizedContent = DOMPurify.sanitize(new TextDecoder().decode(content), cfg)
		let dom = new DOMParser().parseFromString(sanitizedContent, 'text/html')
		let img_contents = [...dom.getElementsByTagName('img')]

		for(el of img_contents) {
			let a = dom.createElement('a')

			a.setAttribute('image-src', el.getAttribute('src'))
			a.setAttribute('href', 'javascript:void(0);')
			a.setAttribute('onclick', 'HtmlChanLib.onClickImage(this)')
			a.innerHTML = "Essa imagem pode vir de um servidor que você não conhece. Clique aqui para abrir.";

			el.parentNode.replaceChild(a, el)
			a.after(dom.createElement('br'))
		}

		let resultHTML = ""
		resultHTML += dom.documentElement.innerHTML
		return resultHTML
	}

	function toBase64(b) {
		var bin = '';
		for(var i = 0; i < b.byteLength; i++)
			bin += String.fromCharCode(b[i]);
		return btoa(bin)
	}

	async function makeHtmlChan(content) {
		let content_bytes = new TextEncoder().encode(content);
		let compressed_content = await compressGZIP(content_bytes);
		return "@@@@@BEGIN HTML CHAN@@@@@\n" + toBase64(compressed_content) + "\n@@@@@END HTML CHAN@@@@@";
	}

	var lib = { }
	lib.processHtmlChan = processHtmlChan
	lib.makeHtmlChan = makeHtmlChan
	lib.findHtmlChan = findHtmlChan

	lib.onClickImage = function(anchor) {
		let image = document.createElement('img')
		image.setAttribute('src', anchor.getAttribute('image-src'))

		anchor.after(image)
		anchor.remove()
	}
	return lib
})()

$(document).ready(function() {
	
	function makeHtmlChanPost() {
		$(".post .body").each(async function(idx, elem) {
			let lines = elem.innerHTML.split('<br>')
			for(var i = 0; i < lines.length; i++) {
				if(lines[i] == "@@@@@BEGIN HTML CHAN@@@@@") {
					i += 2;
					if(i < lines.length && lines[i] == "@@@@@END HTML CHAN@@@@@") {
						lines[i - 2] = ""
						lines[i] = "<br>"

						lines[i - 1] = 
							'<div style="border:1px solid black;display:inline flow-root">'
							+ '<div style="background-color:black;color:white;">HTMLchan</div>'
							+ '<div style="padding:5px">'
							+ await HtmlChanLib.processHtmlChan(lines[i - 1]) 
							+ '</div>'
							+ '</div>'
					}
				} else {
					lines[i] += '<br>'
				}
			}

			elem.innerHTML = ""
			for(var i = 0; i < lines.length; i++) {
				elem.innerHTML += lines[i]
			}
		})
	}

	setTimeout(function() {
		let my_tr = document.createElement('tr');
		let post_tr = document.querySelector("#body").parentNode.parentNode

		post_tr.before(my_tr)

		let htmlchan_header_td = document.createElement('td')
		let htmlchan_header = document.createElement("th")

		htmlchan_header.innerHTML = "HTMLchan";
		htmlchan_header_td.append(htmlchan_header)

		my_tr.append(htmlchan_header_td)

		let make_html_chan_td = document.createElement('td')
		my_tr.append(make_html_chan_td)

		let make_html_chan = document.createElement('a')
		make_html_chan.innerHTML = "Fazer HTMLChan"
		make_html_chan.setAttribute('href', 'javascript:void(0);')
		make_html_chan.onclick = async function() {
			let body = document.forms[0].elements['body']
			let start = body.selectionStart
			let end = body.selectionEnd

			let htmlchan = await HtmlChanLib.makeHtmlChan(body.value.substring(start, end))

			let content = ""
			content += body.value.substring(0, start)
			content += htmlchan
			content += body.value.substring(end, body.value.length)
			body.value = content
		}
		make_html_chan_td.append(make_html_chan)
		make_html_chan_td.append(' ')

		let make_html_chan_mdown = document.createElement('a')
		make_html_chan_mdown.innerHTML = "Fazer HTMLChan com Markdown"
		make_html_chan_mdown.setAttribute('href', 'javascript:void(0);')
		make_html_chan_mdown.onclick = async function() {
			let body = document.forms[0].elements['body']
			let start = body.selectionStart
			let end = body.selectionEnd
			let substr = body.value.substring(start, end)
			let parse = marked.parse(substr)

			let htmlchan = await HtmlChanLib.makeHtmlChan(parse)

			let content = ""
			content += body.value.substring(0, start)
			content += htmlchan
			content += body.value.substring(end, body.value.length)
			body.value = content
		}
		make_html_chan_td.append(make_html_chan_mdown)

		$(document).on("new_post", makeHtmlChanPost)

		makeHtmlChanPost()
	}, 1000)
})