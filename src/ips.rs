use crate::utils::*;

use std::fs::write;
use std::path::Path;

const OFFSET_SIZE: usize = 3;
const SIZE_SIZE: usize = 2;

const IPS_HEADER: &[u8] = b"PATCH";
const IPS_FOOTER: &[u8] = b"EOF";

pub fn patch_ips<P: AsRef<Path>>(src_file: &P, patch_file: &P, out_file: &P) -> Result<(), &'static str> {
    let src = read_file(src_file);
    let patch = read_file(patch_file);

    let out = apply_ips(&src, &patch);
    match out {
        Ok(dst) => {
            write(out_file, dst).expect("Unable to open output file");
            Ok(())
        },
        Err(e) => {
            Err(e)
        }
    }
}

fn apply_ips(src: &Vec<u8>, patch: &[u8]) -> Result<Vec<u8>, &'static str> {
    let mut target = src.clone();

    // Verify that this patch file is indeed valid IPS
    for (i, &byte) in IPS_HEADER.iter().enumerate() {
        if patch[i] != byte {
            return Err("This is not a valid IPS patch file");
        }
    }

    let footer_offset = patch.len() - IPS_FOOTER.len();
    for (i, &byte) in IPS_FOOTER.iter().enumerate() {
        if patch[i + footer_offset] != byte {
            return Err("This is not a valid IPS patch file");
        }
    }

    let mut idx = IPS_FOOTER.len();
    loop {
        if idx == footer_offset {
            break;
        } else if idx > footer_offset {
            return Err("End of file was overrun");
        }

        let mut rle = false;
        let offset = pack_u24(&patch[idx..(idx + OFFSET_SIZE)]);
        idx += OFFSET_SIZE;
        let mut size = pack_u16(&patch[idx..(idx + SIZE_SIZE)]);
        idx += SIZE_SIZE;

        if size == 0 {
            rle = true;
            size = pack_u16(&patch[idx..(idx + SIZE_SIZE)]);
            idx += SIZE_SIZE;
        }

        if offset + size > target.len() {
            return Err("This patch file is corrupted");
        }

        if rle {
            let data = patch[idx];
            for i in 0..size {
                target[offset + i] = data;
            }
            idx += 1;
        } else {
            for i in 0..size {
                target[offset + i] = patch[idx + i];
            }
            idx += size;
        }
    }

    Ok(target)
}
