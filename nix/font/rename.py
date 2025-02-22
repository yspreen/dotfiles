from fontTools import ttLib
import os
import shutil
import argparse


def rename_font_family(input_path, new_family_name):
    """
    Replace the family name of a TTF font file in place, preserving variable font information.

    Args:
        input_path (str): Path to the input TTF file
        new_family_name (str): New family name to set

    Returns:
        bool: True if successful
    """
    # Create a backup of the original file
    backup_path = input_path + ".backup"
    shutil.copy2(input_path, backup_path)

    try:
        # Load the font file
        font = ttLib.TTFont(input_path)

        # Update name table entries
        name_table = font["name"]

        # Family name IDs to modify
        family_name_ids = [1, 16, 21]  # Regular, Preferred, WWS Family Name

        # Iterate through name records
        for record in name_table.names:
            if record.nameID in family_name_ids:
                # Handle different platform encodings
                if record.platformID == 0:  # Unicode
                    record.string = new_family_name
                elif record.platformID == 1:  # Mac
                    record.string = new_family_name.encode("mac_roman")
                elif record.platformID == 3:  # Windows
                    record.string = new_family_name.encode("utf-16be")

        # Handle fvar table for variable fonts if present
        if "fvar" in font:
            for instance in font["fvar"].instances:
                if hasattr(instance, "subfamilyNameID"):
                    # Update instance names while preserving variation info
                    instance_record = name_table.getName(
                        instance.subfamilyNameID, 3, 1, 0x409
                    )
                    if instance_record:
                        instance_record.string = (
                            f"{new_family_name} {instance_record.toStr()}"
                        )

        # Save the modified font back to the original file
        font.save(input_path)
        return True

    except Exception as e:
        # Restore backup if something goes wrong
        if os.path.exists(backup_path):
            shutil.copy2(backup_path, input_path)
        raise Exception(f"Error modifying font: {str(e)}")

    finally:
        # Clean up backup
        if os.path.exists(backup_path):
            os.remove(backup_path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Rename TTF font family")
    parser.add_argument("font_path", help="Path to the TTF font file")
    parser.add_argument("new_name", help="New font family name")

    args = parser.parse_args()

    try:
        success = rename_font_family(args.font_path, args.new_name)
        if success:
            print(f"Font family name successfully changed to: {args.new_name}")
    except Exception as e:
        print(f"Error: {str(e)}")
