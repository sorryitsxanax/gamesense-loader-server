const express = require('express');
const WebSocket = require('ws');
const mongoose = require('mongoose');
const fs = require('fs').promises;
const path = require('path');
const axios = require('axios');
const base64url = require('base64-url');

const app = express();
const PORT = process.env.PORT || 3000;

mongoose.connect('mongodb://localhost:27017/ ? ? ? ?authSource= ? ? ? ?', {
    user: "? ? ? ?",
    pass: "? ? ? ?",
})
.then(() => {
    console.log('Connected to MongoDB');
})
.catch((err) => {
    console.error('MongoDB connection error:', err);
});


const userSchema = new mongoose.Schema({
    login: String,
    senha: String,
    grupo_id: { type: Number, default: 0 }  
});
const User = mongoose.model('User', userSchema);

const luaSchema = new mongoose.Schema({
    nome: String,
    grupo_id: Number
});
const Lua = mongoose.model('Lua', luaSchema);


const loggedInUsers = new Map();


const server = app.listen(PORT, () => {
    console.log(`HTTP Server running on port ${PORT}`);
});

async function doshit(userGroupId) {
    const luasPath = '/root/wannnacry/LUAS'; 
    const luaNames = [];

    try {
        const files = await fs.readdir(luasPath);

        for (const file of files) {
            let existingLua = await Lua.findOne({ nome: file });

            if (!existingLua) {
                existingLua = new Lua({ nome: file, grupo_id: userGroupId });
                await existingLua.save();
            } else if (existingLua.grupo_id <= userGroupId) {
                luaNames.push(existingLua.nome);
            }
        }
        return luaNames;
    } catch (err) {
        console.error('Error verifying and adding moons:', err);
        return [];
    }
}

doshit(1);


const wss = new WebSocket.Server({ server });
console.log(wss);

wss.on('connection', (ws) => {
    console.log('New WebSocket connection');

    ws.on('message', async (message) => {
        try {
            const data = JSON.parse(message);
            const { type, login, senha } = data;

            switch (type) {
                case 'register':
                    const newUser = new User({ login, senha, grupo_id: 0 }); 
                    await newUser.save();
                    ws.send(JSON.stringify({ type: 'register', success: true }));
                    break;
                case 'login':
                    const user = await User.findOne({ login });
                    if (user && user.senha === senha) {
                        
                        loggedInUsers.set(ws, user);
                        ws.send(JSON.stringify({ type: 'login', success: true, login: user.login }));

                        
                        const accessibleLuaNames = await doshit(user.grupo_id);
                        ws.send(JSON.stringify({ type: 'luas', luas: accessibleLuaNames }));

                        
                        ws.user = user;
                    } else {
                        ws.send(JSON.stringify({ type: 'login', success: false, message: 'Bad login or password' }));
                    }
                    break;
                case 'load_lua':
                   
                    if (loggedInUsers.has(ws)) {
                        const user = loggedInUsers.get(ws);
                        const luaName = data.lua;

                        try {
                            
                            const response = await axios.get(`http://sensical.club/api/generatelink/${luaName}`);
                            const temporaryLink = response.data.link;

                            
                            ws.send(JSON.stringify({ type: 'lua_link', luaName, link: temporaryLink }));
                            console.log(`[WS] Sending Lua link for ${luaName} to ${user.login}`);
                        } catch (error) {
                            console.error(`[WS] Error getting Lua link for ${luaName}:`, error.message);
                            ws.send(JSON.stringify({ type: 'error', message: `Error getting Lua link for ${luaName}` }));
                        }
                    } else {
                        ws.send(JSON.stringify({ type: 'error', message: 'Unauthorized access: User not logged in' }));
                    }
                    break;
                case 'ws_send':
                    
                    if (loggedInUsers.has(ws)) {
                        const user = loggedInUsers.get(ws);
                        console.log(`[WS] Sending message to ${user.login}: `, data.message);
                        ws.send(JSON.stringify({ type: 'ws_send', success: true, message: 'Message sent successfully' }));
                    } else {
                        ws.send(JSON.stringify({ type: 'error', message: 'ERROR: User not logged in' }));
                    }
                    break;
                default:
                    ws.send(JSON.stringify({ type: 'error', message: 'Unknown command' }));
            }
        } catch (error) {
            console.error('Error processing message:', error);
            ws.send(JSON.stringify({ type: 'error', message: 'Error processing message' }));
        }
    });

    ws.on('close', () => {
       
        if (loggedInUsers.has(ws)) {
            loggedInUsers.delete(ws);
        }
    });
});
