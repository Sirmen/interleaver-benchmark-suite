function codec = getRSCodec(kind, n, k, frameLen)
%GETRSCODEC  One owner for the RS System objects. Built once, reused.
%
%   dec = getRSCodec('decoder', n, k, frameLen)
%   enc = getRSCodec('encoder', n, k)          frameLen defaults to k
%   getRSCodec('clear')                        drop both, release them
%
% WHY A SEPARATE FUNCTION AND NOT A FIELD IN config
% ---------------------------------------------------------------------------
% The obvious move is to build the objects in configure_FEC_parameters and
% carry them as config.FECencoder / config.FECdecoder. It is more visible than
% a hidden persistent, and that is a real virtue. But config is the wrong
% container for these four reasons:
%
% 1. save_results SAVES config. comm.RSDecoder is a handle object with an
%    internal lock state; writing it into a .mat bloats the results file and
%    reloading it gives back an object whose lock state is whatever it was
%    when saved. Results files should hold numbers, not live objects.
%
% 2. HANDLE SEMANTICS. Copying a struct copies the handle, not the object, so
%    every copy of config aliases ONE decoder. The moment two places call
%    step() with different frame lengths they fight over the same lock, and
%    the failure ("Changing the size on input 1 is not allowed...") surfaces
%    far from the cause.
%
% 3. parfor. A System object cannot be shared across workers. A persistent
%    inside a function is per-worker and simply works; a handle in a
%    broadcast struct does not. Parallelising the size loop is the obvious
%    next speed-up, and this keeps that door open.
%
% 4. THE LOCK DEPENDS ON FRAME LENGTH, WHICH CHANGES PER N. So the object
%    cannot just be built once at configure time and left alone - something
%    has to decide when to release and rebuild. Putting that decision in
%    config means config has behaviour, not just values.
%
% A named accessor keeps the visibility (grep for getRSCodec, clear it by
% name) without any of that. Callers keep their existing signatures.
%
% THE COST THIS AVOIDS
% Profiled over 15 trials: decoderRS_CW took 2.404 s of which
% RSDecoder.setupImpl was 2.038 s and the actual decode 0.206 s. Eighty-five
% per cent of RS decoding was construction, because a fresh object was built
% and released on every call while (n,k) never changed. decodeRS_all calls it
% once per method, so one trial paid for ~25 identical constructions.
%
% R.T. Sirmen harness, 2026

   persistent DEC ENC decKey encKey

   if nargin >= 1 && strcmpi(kind, 'clear')
      if ~isempty(DEC), try, release(DEC); catch, end, end
      if ~isempty(ENC), try, release(ENC); catch, end, end
      DEC = []; ENC = []; decKey = []; encKey = [];
      codec = [];
      return;
   end

   switch lower(kind)
      case 'decoder'
         if nargin < 4 || isempty(frameLen)
            error('getRSCodec: the decoder needs frameLen - its lock depends on it');
         end
         % The decoder is handed a WHOLE frame (many codewords) and returns
         % errInfo per codeword, so its locked input size is the frame length
         % and changes with N. Rebuild only when it actually changes: within
         % one trial all 24 methods share a length, so this fires once per
         % encoded length, not once per call.
         key = [n, k, frameLen];
         if isempty(DEC) || ~isequal(decKey, key)
            if ~isempty(DEC), release(DEC); end
            DEC = comm.RSDecoder;
            DEC.BitInput = false;
            DEC.MessageLength = k;
            DEC.CodewordLength = n;
            DEC.NumCorrectedErrorsOutputPort = true;
            decKey = key;
         end
         codec = DEC;

      case 'encoder'
         % encoderRS_CW feeds ONE codeword's worth of symbols per step(), so
         % the encoder's input size is always k. It never needs releasing for
         % a length change - only if (n,k) themselves change, which they do
         % not during a sweep.
         key = [n, k];
         if isempty(ENC) || ~isequal(encKey, key)
            if ~isempty(ENC), release(ENC); end
            ENC = comm.RSEncoder;
            ENC.BitInput = false;
            ENC.MessageLength = k;
            ENC.CodewordLength = n;
            encKey = key;
         end
         codec = ENC;

      otherwise
         error('getRSCodec: kind must be ''encoder'', ''decoder'' or ''clear'' (got ''%s'')', kind);
   end
end
