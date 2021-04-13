use std::fs::File;
use std::io::Read;
use std::path::Path;

pub fn pack_u24(data: &[u8]) -> usize {
    let mut ret = (data[0] as usize) << 16;
    ret |= (data[1] as usize) << 8;
    ret |= data[2] as usize;
    ret
}

pub fn pack_u16(data: &[u8]) -> usize {
    let mut ret = (data[0] as usize) << 8;
    ret |= data[1] as usize;
    ret
}

pub fn read_file<P: AsRef<Path>>(filename: &P) -> Vec<u8> {
    let mut buffer: Vec<u8> = Vec::new();
    let mut f = File::open(filename).expect("Error opening file");
    f.read_to_end(&mut buffer).expect("Error reading to buffer");
    buffer
}
