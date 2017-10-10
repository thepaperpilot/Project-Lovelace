let socket = io();

let log = document.getElementById('log')
let input = document.getElementById('input')

socket.on('connect', () => {
	input.className = 'middle input'
	input.querySelector('input').disabled = false
	log.innerHTML = ''
})

socket.on('disconnect', () => {
	input.className = 'middle input error'
	input.querySelector('input').disabled = true
})

socket.on('stdout', (string) => {
	appendToLog(string, "stdout")
})

input.addEventListener('submit', function (e) {
	e.preventDefault()
	let input = e.target.querySelector('input')
	appendToLog(input.value, "stdin")
	socket.emit('stdin', input.value)
	input.value = ''
})

function appendToLog(string, className) {
	let element = document.createElement('div')
	element.className = className
	element.innerText = string
	log.append(element)
	log.scrollTop = log.scrollHeight;
}
