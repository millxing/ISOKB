-- ISOKB
-- v2.2.8 @spunoza
-- llllllll.co/t/norns-code-review/14851/39
--
-- 2-channel MIDI keyboard for Norns and Grid                                                  
-- Isomorphic "in key" note layout (similar to Ableton Push)
-- Select a tonic note and one of nine 7-note scales (default C Major)
-- Two independent keyboards, each sends MIDI to a different MIDI channel  
-- Left hand notes go to MIDI 1
-- Right hand notes go to MIDI 2
-- There will be multiple buttons for each note and all buttons corresponding to a pressed note will light up 
--
-- Rob Schoen 
-- millxing at gmail
-- https://llllllll.co/u/spunoza/summary
-- https://github.com/millxing/ISOKB

engine.name = 'PolyPerc'

local music = require 'musicutil'

local midi_channel_left
local midi_channel_right
local mode
local toniclist
local tonicnum
local scale
local pressed = {}
local notes = {}
local root = {}

local g = grid.connect()
local m = midi.connect()

function init()
    
    -- change these paramters to send the MIDI to channels other than 1 & 2
    midi_channel_left = 1
    midi_channel_right = 2
    
    math.randomseed(os.time())
    opening_animation()
    
    mode = 1
    toniclist = music.NOTE_NAMES
    tonicnum = 1
    
    new_scale()
    redraw()
    redraw_grid()
end

function new_scale()
    
    -- fill scal with notes from selected scale
    scale = music.generate_scale_of_length(36+(tonicnum-1),music.SCALES[mode].name,80)
    local base = scale[1] % 12
    
    -- initialize keyboard
    pressed = {}
    notes = {}
    root = {}
    local c
    local r
    for c = 1,16 do
        pressed[c] = {}
        notes[c] = {}
        root[c] = {}
        for r = 8,1,-1 do
            pressed[c][r] = 0
            notes[c][r] = 0
            root[c][r] = 0
        end    
    end    
    
    -- fill notes and root table
    local temp
    local i
    for r = 8,1,-1 do
        for c = 1,7 do
            if r==8 then
                notes[c][8] = scale[c]
                notes[c+9][8] = scale[c]
                if notes[c][8] % 12 == base then root[c][8] = 1; end
                if notes[c+9][8] % 12 == base then root[c+9][8] = 1; end
            else
                for i = 1,#scale do 
                    if notes[c][r+1] == scale[i] then temp = i; end
                end
                notes[c][r] = scale[temp+3]
                notes[c+9][r] = scale[temp+3]
                if notes[c][r] % 12 == base then 
                    root[c][r] = 1; 
                    root[c+9][r] = 1; 
                end
            end    
        end    
    end
    clearAllNotes()
end    

function g.key(x, y, z)    
    
    -- events for button press
    if z==1 then 
        pressed[x][y] = 1
        if x > 8 then cplus = 9 else cplus = 0 end
        for c = 1,7 do
            for r = 1,8 do
                if notes[c+cplus][r] == notes[x][y] then
                    pressed[c+cplus][r] = 1
                end    
            end    
        end 
        print(x,y,notes[x][y], music.note_num_to_name(notes[x][y]))
        if x<9 then
            m:note_on(notes[x][y],90,1)
        else    
            m:note_on(notes[x][y],90,2)
        end    
    end
    
    --events for button release
    if z==0 then 
        pressed[x][y] = 0
        if x > 8 then cplus = 9 else cplus = 0 end
        for c = 1,7 do
            for r = 1,8 do
                if notes[c+cplus][r] == notes[x][y] then
                    pressed[c+cplus][r] = 0
                end    
            end    
        end 
        if x<9 then
            m:note_off(notes[x][y],0,1)
        else
            m:note_off(notes[x][y],0,2)
        end    
    end
    
    redraw_grid()    
end

function redraw_grid()
    g:all(2)
    local r
    local c
    for r = 8,1,-1 do
        for c = 1,7 do 
            g:led(c,r,pressed[c][r]==1 and 15 or (root[c][r]==1 and 10 or 5))
            g:led(c+9,r, pressed[c+9][r]==1 and 15 or (root[c+9][r]==1 and 10 or 5))
        end
    end
    g:refresh()
end  

function redraw()
    screen.clear()
    screen.font_size(8)
    screen.level(15)
    screen.move(0,10)
    screen.text("left side is MIDI ch 1")
    screen.move(0,20)
    screen.text("right side is MIDI ch 2")
    screen.move(0,30)
    screen.text("encoder 2 changes root note")
    screen.move(0,40)
    screen.text("encoder 3 changes scale")
    screen.move(0,60)
    screen.text("scale: " .. toniclist[tonicnum] .. " " .. music.SCALES[mode].name)
    screen.update()
end  

function enc(n,d)
    -- select tonic note
    if n==2 then
        tonicnum = tonicnum + d
        if tonicnum>12 then tonicnum = 1; end
        if tonicnum<1 then tonicnum = 12; end
        new_scale()
    end
    -- select scale
    if n==3 then
        mode = mode + d
        if mode>9 then mode = 1; end
        if mode<1 then mode = 9; end
        new_scale()
    end
    redraw()
end

-- gratuitous opening animation
function opening_animation()
    local a; local i; local j
    local speed = .05
    for a = 8,1,-1 do 
        g:all(0)
        for i = 1,8 do
            for j = 1+(a-1),16-(a-1) do
                g:led(j,i,math.random(0,15))
            end
        end
        g:refresh()
        sleep(speed)
    end
    for a = 1,8 do
        g:all(0)
        for i = 1,8 do
            for j = 1+(a-1),16-(a-1) do
                g:led(j,i,math.random(0,15))
            end
        end
        g:refresh()
        sleep(speed)
    end
    g:all(0)
    g:refresh()
end    

-- pause or delay lua code
function sleep(s)
  local ntime = os.clock() + s
  repeat until os.clock() > ntime
end

-- clear midi buffer in case of stuck notes
function clearAllNotes()
    local i; local j
    for i = 1,2 do
        for j = 1,127 do
            m:note_off(j,0,i)
        end
    end
end
