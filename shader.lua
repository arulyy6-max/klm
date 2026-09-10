local ffi = require("ffi")
local gta = ffi.load("GTASA")

local cast = ffi.cast

ffi.cdef([[
    typedef struct FILE FILE;
    FILE*  fopen(const char* path, const char* mode);
    int    fclose(FILE* f);
    long   ftell(FILE* f);
    int    fseek(FILE* f, long offset, int whence);
    size_t fread(void* buf, size_t size, size_t count, FILE* f);

    const char* blurPShader;
    const char* gradingPShader;
    const char* shadowResolvePShader;
    const char* contrastVShader;
    const char* contrastPShader;
]])

local scriptPath = thisScript().path
local scriptDir = scriptPath:match('(.*/)') or scriptPath:match('(.*\\)') or ''
local SHADER_DIR = scriptDir .. 'shaders/'

local allLoaded = true

local function loadShader(fileName, symbolName)
  local file = ffi.C.fopen(SHADER_DIR .. fileName, "rb")
  if file == nil then
    allLoaded = false
    print("[Shaders] failed to load " .. fileName)
    return
  end
  ffi.C.fseek(file, 0, 2)
  local size = ffi.C.ftell(file)
  ffi.C.fseek(file, 0, 0)
  local raw = ffi.new("char[?]", size + 1)
  ffi.C.fread(raw, 1, size, file)
  ffi.C.fclose(file)
  local text = ffi.string(raw, size):gsub("\\t", "\t"):gsub("\\n", "\n")
  local buffer = ffi.new("char[?]", #text + 1)
  ffi.copy(buffer, text)
  gta[symbolName] = cast("const char*", buffer)
  print("[Shaders] loaded " .. fileName)
end

loadShader('ps/blurPS.glsl', 'blurPShader')
loadShader('ps/gradingPS.glsl', 'gradingPShader')
loadShader('ps/shadowResolvePS.glsl', 'shadowResolvePShader')
loadShader('vs/contrastVS.glsl', 'contrastVShader')
loadShader('ps/contrastPS.glsl', 'contrastPShader')

if allLoaded then
  print("[Shaders] Shaders Loader - Deprau")
else
  print("[Shaders] some shaders failed to load")
end

function main()
  wait(-1)
end