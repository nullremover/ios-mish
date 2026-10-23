
import JavaScriptKit

let document = JSObject.global.document
let body = document.body

let heading = document.createElement("h1")
heading.textContent = "mish"

let subtitle = document.createElement("p")
subtitle.textContent = "your music, your way."

let status = document.createElement("p")
status.textContent = "Mish Web is running."

let button = document.createElement("button")
button.textContent = "It works!"

let style = document.createElement("style")
style.textContent = """
    body {
        background: #080808;
        color: #f2f2f2;
        font-family: system-ui, sans-serif;
        padding: 40px;
    }

    h1 {
        color: #a6e3a1;
        font-size: 3rem;
    }

    p {
        color: #9294a1;
    }

    button {
        background: #a6e3a1;
        color: #080808;
        border: none;
        border-radius: 8px;
        padding: 12px 18px;
        font-size: 1rem;
        cursor: pointer;
    }
    """

body.appendChild(style)
body.appendChild(heading)
body.appendChild(subtitle)
body.appendChild(status)
body.appendChild(button)
