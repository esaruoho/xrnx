--[[============================================================================
xSample
============================================================================]]--
--[[

  Methods for working with samples

]]

class 'xSample'

xSample.SAMPLE_INFO = {
  EMPTY = 1,
  SILENT = 2,
  PAN_LEFT = 4,
  PAN_RIGHT = 8,
  DUPLICATE = 16,
  MONO = 32,
  STEREO = 64,
}

xSample.SAMPLE_CHANNELS = {
  LEFT = 1,
  RIGHT = 2,
  BOTH = 3,
}

xSample.SAMPLE_INTERPOLATION = {
  NONE = 1,
  LINEAR = 2,
  CUBIC = 3,
  SINC = 4,
}

xSample.SAMPLE_INTERPOLATION_LABELS = {
  "None",
  "Linear",
  "Cubic",
  "Sinc",
}

--- SAMPLE_CONVERT: misc. channel operations
-- MONO_MIX: stereo -> mono mix (mix left and right) TODO
-- MONO_LEFT: stereo -> mono (keep left)
-- MONO_RIGHT: stereo -> mono (keep right)
-- STEREO: mono -> stereo
-- SWAP: stereo (swap channels) TODO
-- KEEP: do not change anything
xSample.SAMPLE_CONVERT = {
  MONO_MIX = 1, 
  MONO_LEFT = 2,
  MONO_RIGHT = 3,
  STEREO = 4,
  SWAP = 5, 
  KEEP = 6,
}

xSample.BIT_DEPTH = {0,8,16,24,32}


--------------------------------------------------------------------------------
-- @param sample (renoise.Sample)
-- @return int (0 when no sample data)

function xSample.get_bit_depth(sample)
  --TRACE("xSample.get_bit_depth(sample)",sample)

  -- how often to dispatch yield()
  local yield_counter = 5000
  local count = 0

  local function reverse(t)
    local nt = {}
    local size = #t + 1
    for k,v in ipairs(t) do
      nt[size - k] = v
    end
    return nt
  end
  
  local function tobits(num)
    local t = {}
    while num > 0 do
      local rest = num % 2
      t[#t + 1] = rest
      num = (num - rest) / 2
    end
    t = reverse(t)
    return t
  end
  
  -- Vars and crap
  local bit_depth = 0
  local sample_max = math.pow(2, 32) / 2
  local buffer = sample.sample_buffer
  
  -- If we got some sample data to analyze
  if (buffer.has_sample_data) then
  
    local channels = buffer.number_of_channels
    local frames = buffer.number_of_frames
    
    for f = 1, frames do
      for c = 1, channels do
      
        -- Convert float to 32-bit unsigned int
        local s = (1 + buffer:sample_data(c, f)) * sample_max
        
        -- Measure bits used
        local bits = tobits(s)
        for b = 1, #bits do
          if bits[b] == 1 then
            if b > bit_depth then
              bit_depth = b
            end
          end
        end

      end

      count = count + 1
      if (count > yield_counter)  then
        count = 0      
        --print("yield at frame",f)
        coroutine.yield()
      end

    end
  end
    
  return xSample.bits_to_xbits(bit_depth),bit_depth

end

--------------------------------------------------------------------------------
-- convert any bit-depth to a valid xSample representation
-- @param num_bits (int)
-- @return int (xSample.BIT_DEPTH)

function xSample.bits_to_xbits(num_bits)
  TRACE("xSample.bits_to_xbits(num_bits)",num_bits)

  if (num_bits == 0) then
    return 0
  end
  for k,xbits in ipairs(xSample.BIT_DEPTH) do
    if (num_bits <= xbits) then
      return xbits
    end
  end
  error("Number is outside allowed range")

end

--------------------------------------------------------------------------------
-- @param sample (renoise.Sample)
-- @return int (xSample.BIT_DEPTH), zero means no data

function xSample.get_sample_bit_depth(sample)
  TRACE("xSample.get_sample_bit_depth(sample)",sample)

  if not sample.sample_buffer.has_sample_data then
    return 0
  else
    return sample.sample_buffer.bit_depth
  end

end

--------------------------------------------------------------------------------
-- @param sample (renoise.Sample)
-- @return int (1 or 2 for channels, zero means no data)

function xSample.get_sample_channel_count(sample)
  TRACE("xSample.get_sample_channel_count(sample)",sample)

  if not sample.sample_buffer.has_sample_data then
    return 0
  else
    return sample.sample_buffer.number_of_channels
  end

end

--------------------------------------------------------------------------------
-- @param sample (renoise.Sample)
-- @return int (xSample.BIT_DEPTH), zero means no data

function xSample.get_sample_rate(sample)
  TRACE("xSample.get_sample_rate(sample)",sample)

  if not sample.sample_buffer.has_sample_data then
    return 0
  else
    return sample.sample_buffer.sample_rate
  end

end

--------------------------------------------------------------------------------
-- @param sample (renoise.Sample)
-- @return int (xSample.SAMPLE_INTERPOLATION) or nil

function xSample.get_sample_interpolation_mode(sample)
  TRACE("xSample.get_sample_interpolation_mode(sample)",sample)

  if not sample.sample_buffer.has_sample_data then
    return 
  else
    return sample.interpolation_mode
  end

end


--------------------------------------------------------------------------------
-- @param sample (renoise.Sample)
-- @return int (xSample.SAMPLE_INTERPOLATION) or nil

function xSample.get_sample_oversample_enabled(sample)
  TRACE("xSample.get_sample_oversample_enabled(sample)",sample)

  if not sample.sample_buffer.has_sample_data then
    return 
  else
    return sample.oversample_enabled
  end

end


--------------------------------------------------------------------------------
-- check if sample has duplicate channel data, is hard-panned or silent
-- (several detection functions in one means less methods are needed...)
-- @param sample  (renoise.Sample)
-- @return enum (xSample.SAMPLE_[...])
-- @return number (peak_level)

function xSample.get_channel_info(sample,check_for_peak)
  TRACE("xSample.get_channel_info(sample)",sample,check_for_peak)

  local peak_level = 0
  local buffer = sample.sample_buffer
  if not buffer.has_sample_data then
    return xSample.SAMPLE_INFO.EMPTY,peak_level
  end

  -- how often to dispatch yield()
  local yield_counter = 5000
  local count = 0

  local silent = true
  local l_pan = (buffer.number_of_channels == 2) and true or false
  local r_pan = (buffer.number_of_channels == 2) and true or false
  local duplicate = (buffer.number_of_channels == 2) and true or false
  local l = nil
  local r = nil
  local frames = buffer.number_of_frames
  for f = 1, frames do

    if (buffer.number_of_channels == 1) then     
      
      local s = buffer:sample_data(1,f)
      if (buffer:sample_data(1,f) ~= 0) then
        silent = false
        peak_level = math.max(peak_level,math.abs(s))
      end

    else

      l = buffer:sample_data(1,f)
      r = buffer:sample_data(2,f)

      if (l ~= 0) then
        silent = false
        r_pan = false
        peak_level = math.max(peak_level,math.abs(l))
        --print("l,peak_level",l,peak_level)
      end
      if (r ~= 0) then
        silent = false
        l_pan = false
        peak_level = math.max(peak_level,math.abs(r))
        --print("r,peak_level",r,peak_level)
      end
      if (l ~= r) then
        duplicate = false
        if not check_for_peak then
          -- no need to scan further
          if not silent and not r_pan and not l_pan then
            return xSample.SAMPLE_INFO.STEREO,peak_level
          end
        end
      end   
      
    end

    count = count + 1
    if (count > yield_counter)  then
      count = 0      
      --print("yield at frame",f)
      coroutine.yield()
    end

  end

  if silent then
    return xSample.SAMPLE_INFO.SILENT,peak_level
  elseif duplicate then
    return xSample.SAMPLE_INFO.DUPLICATE,peak_level
  elseif r_pan then
    return xSample.SAMPLE_INFO.PAN_RIGHT,peak_level
  elseif l_pan then
    return xSample.SAMPLE_INFO.PAN_LEFT,peak_level
  end

  return xSample.SAMPLE_INFO.STEREO,peak_level

end

--------------------------------------------------------------------------------
-- convert sample: change bit-depth, perform channel operations, crop etc.
-- (jumping through a few hoops to keep keyzone and phrases intact...)
-- @param instr (renoise.Instrument)
-- @param sample_idx (int)
-- @param bit_depth (xSample.BIT_DEPTH)
-- @param channel_action (xSample.SAMPLE_CONVERT)
-- @param range (table) source start/end frames, if undefined use whole sample
-- @param level (number) multiply by this amount, if undefined leave unchanged
-- @return renoise.Sample or nil (when failed to convert)

function xSample.convert_sample(instr,sample_idx,bit_depth,channel_action,range,level)
  TRACE("xSample.convert_sample(instr,sample_idx,bit_depth,channel_action,range,level)",instr,sample_idx,bit_depth,channel_action,range,level)

  local sample = instr.samples[sample_idx]
  local buffer = sample.sample_buffer
  if not buffer.has_sample_data then
    return false
  end

  local start_frame = (range) and (range.start_frame) or 1
  local num_frames = (range) and (range.end_frame-range.start_frame+1) or buffer.number_of_frames
  --print("num_frames",num_frames)
  
  local num_channels = buffer.number_of_channels
  if (channel_action == xSample.SAMPLE_CONVERT.STEREO) 
    or (channel_action == xSample.SAMPLE_CONVERT.SWAP) 
  then
    num_channels = 2
  elseif (channel_action == xSample.SAMPLE_CONVERT.MONO_MIX) 
    or (channel_action == xSample.SAMPLE_CONVERT.MONO_LEFT) 
    or (channel_action == xSample.SAMPLE_CONVERT.MONO_RIGHT) 
  then
    num_channels = 1
  end
  --print("num_channels",num_channels)

  local level = (level) and level or 1

  local new_sample = instr:insert_sample_at(sample_idx+1)
  local new_buffer = new_sample.sample_buffer
  local success = new_buffer:create_sample_data(
    buffer.sample_rate, 
    bit_depth, 
    num_channels,
    num_frames)  

  if not success then
    error("Failed to create sample buffer")
  end

  -- detect if instrument is in drumkit mode
  -- (when basenote is shifted by one semitone)
  local drumkit_mode = not ((new_sample.sample_mapping.note_range[1] == 0) and 
    (new_sample.sample_mapping.note_range[2] == 119))

  -- initialize certain aspects of sample
  -- before copying over information...
  new_sample.loop_start = 1
  new_sample.loop_end = num_frames

  xReflection.copy_object_properties(sample,new_sample)

  -- only when copying single channel 
  local channel_idx = 1 
  if(channel_action == xSample.SAMPLE_CONVERT.MONO_RIGHT) then
    channel_idx = 2
  end
  
  -- set sample data (including adjustments - level)
  local set_sample_data = function(buffer,ch_idx,frame_idx,value)
    --print("*** set_sample_data - ",value,value/level)
    buffer:set_sample_data(ch_idx,frame_idx,value/level)
  end

  local f = nil
  new_buffer:prepare_sample_data_changes()
  for f_idx = start_frame,num_frames do

    if(channel_action == xSample.SAMPLE_CONVERT.MONO_MIX) then
      -- TODO mix stereo to mono signal
    elseif(channel_action == xSample.SAMPLE_CONVERT.MONO_LEFT) 
      or (channel_action == xSample.SAMPLE_CONVERT.MONO_RIGHT) 
    then
      -- copy from one channel to target channel(s)
      f = buffer:sample_data(channel_idx,f_idx)
      set_sample_data(new_buffer,1,f_idx,f)
      if (num_channels == 2) then
        f = buffer:sample_data(channel_idx,f_idx)
        set_sample_data(new_buffer,2,f_idx,f)
      end
    elseif(channel_action == xSample.SAMPLE_CONVERT.STEREO) then
      set_sample_data(new_buffer,1,f_idx,buffer:sample_data(1,f_idx))
      set_sample_data(new_buffer,2,f_idx,buffer:sample_data(2,f_idx))
    elseif(channel_action == xSample.SAMPLE_CONVERT.KEEP) then
      if (num_channels == 1) then
        set_sample_data(new_buffer,1,f_idx,buffer:sample_data(1,f_idx))
      else
        set_sample_data(new_buffer,1,f_idx,buffer:sample_data(1,f_idx))
        set_sample_data(new_buffer,2,f_idx,buffer:sample_data(2,f_idx))
      end
    elseif(channel_action == xSample.SAMPLE_CONVERT.SWAP) then
      set_sample_data(new_buffer,1,f_idx,buffer:sample_data(2,f_idx))
      set_sample_data(new_buffer,2,f_idx,buffer:sample_data(1,f_idx))
    end

  end
  new_buffer:finalize_sample_data_changes()
  -- /change sample 

  -- when in drumkit mode, shift back keyzone mappings
  if drumkit_mode then
    xKeyzone.shift_keyzone_by_semitones(instr,sample_idx+2,-1)
  end

  -- rewrite phrases so we don't loose direct sample 
  -- references when deleting the original sample
  for k,v in ipairs(instr.phrases) do
    xPhrase.replace_sample_index_in_phrase(v,sample_idx,sample_idx+1)
  end

  instr:delete_sample_at(sample_idx)

  return new_sample

end

