const express = require('express');
const fs = require('fs').promises;
const path = require('path');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = 80;

const luasDir = path.join(__dirname, '..', 'LUAS');

const tempDir = path.join(__dirname, '..', 'TEMP');


app.use(express.json());
app.use(express.urlencoded({ extended: true }));


app.get('/api/generatelink/:luaName', async (req, res) => {
    const luaName = req.params.luaName;
    const luaFilePath = path.join(luasDir, luaName);

    try {
        const stats = await fs.stat(luaFilePath);


        const tempFileName = uuidv4() + path.extname(luaName);


        await fs.mkdir(tempDir, { recursive: true });


        const tempFilePath = path.join(tempDir, tempFileName);


        await fs.copyFile(luaFilePath, tempFilePath);


        const temporaryLink = `http://sensical.club/api/getlua/${tempFileName}`;
        res.json({ link: temporaryLink });
    } catch (err) {
        console.error('Error generating temporary link for Lua file:', err);
        res.status(500).json({ error: 'Erro ao gerar o link temporário' });
    }
});

app.get('/api/getlua/:luaName', async (req, res) => {
    const luaName = req.params.luaName;
    const luaFilePath = path.join(tempDir, luaName);

    try {
       
        const stats = await fs.stat(luaFilePath);

       
        const luaContent = await fs.readFile(luaFilePath, 'utf-8');

        
        res.set({
            'Content-Type': 'text/plain',
            'Content-Disposition': `attachment; filename="${luaName}"`,
        });

        
        res.send(luaContent);

    
        await fs.unlink(luaFilePath);
    } catch (err) {
        console.error('Error getting Lua file:', err);
        res.status(404).send('File not found');
    }
});



app.get('/ping', (req, res) => {
    res.send('Ping received');
});


const server = app.listen(PORT, () => {
    console.log(`HTTP Server running on port ${PORT}`);
});

module.exports = app;
