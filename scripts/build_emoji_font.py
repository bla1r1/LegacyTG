#!/usr/bin/env python3
import struct, math, os, sys

def make_name_table(family, subfamily, full_name, ps_name):
    records = []
    # Mac Roman (platform 1, encoding 0, lang 0)
    for nid, text in [(1, family), (2, subfamily), (3, f'{ps_name}; 1.0; 2026'), (4, full_name), (5, 'Version 1.0'), (6, ps_name)]:
        records.append((1, 0, 0, nid, text.encode('latin1')))
    # Windows Unicode BMP (platform 3, encoding 1, lang 0x0409)
    for nid, text in [(1, family), (2, subfamily), (3, f'{ps_name}; 1.0; 2026'), (4, full_name), (5, 'Version 1.0'), (6, ps_name)]:
        records.append((3, 1, 0x0409, nid, text.encode('utf-16-be')))
    # Unicode (platform 0, encoding 3, lang 0)
    for nid, text in [(1, family), (2, subfamily), (3, f'{ps_name}; 1.0; 2026'), (4, full_name), (5, 'Version 1.0'), (6, ps_name)]:
        records.append((0, 3, 0, nid, text.encode('utf-16-be')))
    
    num_records = len(records)
    storage_offset = 6 + num_records * 12
    
    table_header = struct.pack('>HHH', 0, num_records, storage_offset)
    record_bytes = bytearray()
    storage_bytes = bytearray()
    
    for pid, eid, lid, nid, sbytes in records:
        off = len(storage_bytes)
        slen = len(sbytes)
        record_bytes.extend(struct.pack('>6H', pid, eid, lid, nid, slen, off))
        storage_bytes.extend(sbytes)
        
    return table_header + bytes(record_bytes) + bytes(storage_bytes)

def enhance_cmap_table(cmap_data):
    # If cmap has only 1 subtable, expose it to (0, 3), (0, 4), and (3, 10)
    ver, num_sub = struct.unpack('>HH', cmap_data[:4])
    if num_sub == 1:
        pid, eid, off = struct.unpack('>HHI', cmap_data[4:12])
        subtable_bytes = cmap_data[off:]
        # New cmap with 3 records: (0, 3), (0, 4), (3, 10)
        # header: 4 bytes, records: 3 * 8 = 24 bytes -> total 28 bytes
        new_header = struct.pack('>HH', 0, 3)
        new_sub_off = 28
        new_records = struct.pack('>HHIHHIHHI',
            0, 3, new_sub_off,
            0, 4, new_sub_off,
            3, 10, new_sub_off
        )
        return new_header + new_records + subtable_bytes
    return cmap_data

def build_ttf(input_ttc, font_offset, output_ttf, strikes_to_keep=(40, 64)):
    with open(input_ttc, 'rb') as f:
        f.seek(font_offset)
        hdr = f.read(12)
        tag, num_tables = struct.unpack('>4sH', hdr[:6])
        records = []
        for _ in range(num_tables):
            t_tag, ck, t_off, t_len = struct.unpack('>4sIII', f.read(16))
            records.append((t_tag.decode('latin1'), t_off, t_len))
        
        tables = {}
        for t_tag, t_off, t_len in records:
            f.seek(t_off)
            tables[t_tag] = f.read(t_len)

    # Replace name table
    tables['name'] = make_name_table(
        family='Apple Color Emoji Compat',
        subfamily='Regular',
        full_name='Apple Color Emoji Compat',
        ps_name='AppleColorEmojiCompat'
    )

    # Enhance cmap table for maximum compatibility
    if 'cmap' in tables:
        tables['cmap'] = enhance_cmap_table(tables['cmap'])

    # Filter sbix strikes
    if 'sbix' in tables and strikes_to_keep is not None:
        sbix_data = tables['sbix']
        ver, flags, num_strikes = struct.unpack('>HHI', sbix_data[:8])
        old_offsets = struct.unpack(f'>{num_strikes}I', sbix_data[8:8+num_strikes*4])
        
        kept_strikes = []
        for i, o in enumerate(old_offsets):
            ppem, ppi = struct.unpack('>HH', sbix_data[o:o+4])
            if ppem in strikes_to_keep:
                next_o = old_offsets[i+1] if i+1 < num_strikes else len(sbix_data)
                strike_bytes = sbix_data[o:next_o]
                kept_strikes.append((ppem, ppi, strike_bytes))
        
        new_num_strikes = len(kept_strikes)
        header_len = 8 + new_num_strikes * 4
        if header_len % 4 != 0:
            header_len += 4 - (header_len % 4)
        
        cur_offset = header_len
        new_strike_offsets = []
        body = bytearray()
        for ppem, ppi, sbytes in kept_strikes:
            new_strike_offsets.append(cur_offset)
            body.extend(sbytes)
            if len(body) % 4 != 0:
                body.extend(b'\x00' * (4 - (len(body) % 4)))
            cur_offset = header_len + len(body)
        
        new_sbix = bytearray()
        new_sbix.extend(struct.pack('>HHI', ver, flags, new_num_strikes))
        for so in new_strike_offsets:
            new_sbix.extend(struct.pack('>I', so))
        while len(new_sbix) < header_len:
            new_sbix.append(0)
        new_sbix.extend(body)
        tables['sbix'] = bytes(new_sbix)

    sorted_tags = sorted(tables.keys())
    num_t = len(sorted_tags)
    
    entry_sel = int(math.floor(math.log2(num_t)))
    search_range = (2 ** entry_sel) * 16
    range_shift = num_t * 16 - search_range
    
    header = struct.pack('>I4H', 0x00010000, num_t, search_range, entry_sel, range_shift)
    data_offset = 12 + num_t * 16
    if data_offset % 4 != 0:
        data_offset += 4 - (data_offset % 4)
    
    def calc_checksum(data):
        pad_len = (4 - (len(data) % 4)) % 4
        padded = data + b'\x00' * pad_len
        count = len(padded) // 4
        words = struct.unpack(f'>{count}I', padded)
        return sum(words) & 0xFFFFFFFF
    
    table_records = []
    table_bodies = []
    
    current_off = data_offset
    for tag in sorted_tags:
        tdata = tables[tag]
        tlen = len(tdata)
        cksum = calc_checksum(tdata)
        table_records.append((tag.encode('latin1'), cksum, current_off, tlen))
        table_bodies.append(tdata)
        pad = (4 - (tlen % 4)) % 4
        if pad:
            table_bodies.append(b'\x00' * pad)
        current_off += tlen + pad
    
    out = bytearray()
    out.extend(header)
    for tag_b, ck, off, tlen in table_records:
        out.extend(struct.pack('>4sIII', tag_b, ck, off, tlen))
    while len(out) < data_offset:
        out.append(0)
    for b in table_bodies:
        out.extend(b)
    
    for tag_b, ck, off, tlen in table_records:
        if tag_b == b'head':
            out[off+8:off+12] = b'\x00\x00\x00\x00'
            file_cksum = calc_checksum(out)
            adj = (0xB1B0AFBA - file_cksum) & 0xFFFFFFFF
            out[off+8:off+12] = struct.pack('>I', adj)
            break
            
    with open(output_ttf, 'wb') as f:
        f.write(out)
    print(f'Successfully built {output_ttf}: {len(out)} bytes ({len(out)/(1024*1024):.2f} MB)')

if __name__ == '__main__':
    src = '/System/Library/Fonts/Apple Color Emoji.ttc'
    offset = 32
    if not os.path.exists(src):
        src = '/tmp/AppleColorEmoji-LQ.ttc'
        offset = 20
    dst = 'resources/fonts/AppleColorEmojiCompat.ttf'
    build_ttf(src, offset, dst, strikes_to_keep=(40, 64))
