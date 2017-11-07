var express = require('express')
var app = require('express')();
var http = require('http').Server(app);
var io = require('socket.io')(http);
let spawn = require('child_process').spawn

const PORT = 3000 // Web page will be available on localhost:3000

// Dictionary of users (socket ids) to objects:
//   process: instance of our verilog program this user is using
let users = {}

app.use(express.static('static'));

app.get('/', function(req, res){
  res.sendFile(__dirname + '/index.html');
});

io.on('connection', function(socket){
  users[socket.id] = {
    process: getNewProcess(socket)
  }
  socket.on('stdin', function(string) {
    // Limit string to 50 characters
    users[socket.id].process.stdin.write(string.slice(0, 49) + "\n")
  })
  socket.on('disconnect', function() {
    delete users[socket.id]
  })
});

http.listen(PORT, function(){
  console.log('listening on *:' + PORT);
});

// This is actually super important. I hope one day it won't be.
// Copied from my(Anthony) message on slack to the team:
/*
It turns out reading from stdin is blocking. The internet seems to disagree, and maybe its just iverilog that has this issue, but whenever I try to read from stdin it will wait until there's something to read, and not run other code in parallel- even in different modules. I tried to make it work for a long time, but at this point I think its a lost cause. So, I used a hack-y solution: I send a noop command every 250ms (this value can obviously be changed). What this means is that no matter what our clocks are in the verilog, if it takes less than 250ms to perform, its really going to be going off that instead
So effectively all our clocks will be on the same interval. Keep that in mind. Sorry for the inconvenience (and use counters to make clocks take longer, that's what I'll be doing with the solar panel bit anyways)
*/
setInterval(() => {
  let keys = Object.keys(users);
  for (let i = 0; i < keys.length; i++) {
    users[keys[i]].process.stdin.write('t\n');
  }
}, 250)

function getNewProcess(socket) {
  let childProcess = spawn(process.platform === 'win32' ? 'vvp a.out' : './a.out')
  // Create hook on our iverilog process that will receive every line of output from our iverilog program
  childProcess.stdout.on('data', (chunk) => {
    let lines = chunk.toString().split('\n')
    lines.forEach((line) => {
      if (line.trim() !== '') socket.emit('stdout', line)
    })
  })
  childProcess.stdout.on('close', (code) => {
    console.log('closed:' + code)
  })
  childProcess.stderr.on('data', (chunk) => {
    console.log('err:' + chunk)
  })

  return childProcess
}
