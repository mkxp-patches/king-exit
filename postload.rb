# King Exit JoiPlay Performance & Stability Patch
# Non-destructive: delete this file at any time to restore original behavior.

begin
  # Pre-warm Oniguruma's Unicode case-fold table cleanly on main thread once
  begin
    "a,b" =~ /\eS\[(\d+),(.*?),(.*?)\]/i
  rescue Exception
  end

  # Fix 1: Skip nonexistent diagonal sprite ("-X") probes on every map/menu exit
  # (149_移動関連拡張.rb probes "<name>-X" for every event; King Exit has 0 "-X" sprites)
  begin
    if defined?(Sprite_Character) && Sprite_Character.method_defined?(:get_cross_character_name)
      class Sprite_Character
        def get_cross_character_name
          @character.set_character_diagonal(false)
          return nil
        end
      end
    end
  rescue Exception
  end

  # Fix 2: Fast-path Langscore's "_en" graphic lookup using the 30 verified
  # Graphics/Pictures/*_en files instead of probing every asset with exceptions
  begin
    if defined?(Langscore) && Cache.respond_to?(:ls_base_load_bitmap)
      module Langscore
        KE_EN_PICTURES = {
          "cg03_02" => true, "cg15_01" => true, "cg22_02" => true,
          "cg34_01" => true, "cg49_01" => true, "cg55_02" => true,
          "ouabe" => true, "ouber" => true, "oubru" => true, "ougui" => true,
          "ouras" => true, "ousam" => true, "ousen" => true, "ousti" => true,
          "robi" => true,
          "ztaitlelogo1" => true, "ztaitlelogo1p" => true,
          "ztaitlelogo2" => true, "ztaitlelogo2p" => true,
          "ztaitlelogo3" => true, "ztaitlelogo3p" => true,
          "ztaitlelogo4" => true, "ztaitlelogo4p" => true,
          "ztaitlelogo5" => true, "ztaitlelogo6" => true,
          "ztaitlelogo7" => true, "ztaitlelogo8" => true,
          "ztaitlelogo9" => true, "ztaitlelogo10" => true,
          "ztaitlelogogg" => true
        }
      end

      class << Cache
        alias ke_orig_load_bitmap load_bitmap
        def load_bitmap(folder_name, filename, hue = 0)
          cache_limit_check if respond_to?(:cache_limit_check)
          if filename.nil? || filename.empty?
            return ls_base_load_bitmap(folder_name, "", hue)
          end
          if $langscore_current_language == Langscore::DEFAULT_LANGUAGE && Langscore::ENABLE_TRANSLATION_FOR_DEFLANG == false
            return ls_base_load_bitmap(folder_name, filename, hue)
          end

          path = folder_name + filename
          ts_path = Langscore.translate(path, $ls_graphics_tr)
          if ts_path != path
            filename = ts_path.sub(folder_name, "")
            return ls_base_load_bitmap(folder_name, filename, hue)
          end

          if $langscore_current_language == "en"
            if folder_name.casecmp("Graphics/Pictures/") == 0 && Langscore::KE_EN_PICTURES[filename.downcase]
              filename = filename + "_en"
            end
            return ls_base_load_bitmap(folder_name, filename, hue)
          end

          # Fallback for non-English languages (ja / zh-cn)
          new_filename = filename + "_" + $langscore_current_language
          unless $ls_graphic_cache.has_key?(filename)
            begin
              bitmap = ls_base_load_bitmap(folder_name, new_filename, hue)
              $ls_graphic_cache[filename] = true
              return bitmap
            rescue Exception
              $ls_graphic_cache[filename] = false
            end
          end
          filename = new_filename if $ls_graphic_cache[filename]
          ls_base_load_bitmap(folder_name, filename, hue)
        end
      end
    end
  rescue Exception
  end

  # Fix 3: Raise bitmap cache limit from 40 to 200 to prevent menu/map thrashing
  begin
    if defined?(Cache_Delete)
      Cache.instance_variable_set(:@maximum, 200)
    end
  rescue Exception
  end

  # Fix 4: Speed up LSCSV.parse_col (in-place << instead of quadratic +=)
  begin
    if defined?(LSCSV) && LSCSV.respond_to?(:parse_col)
      class << LSCSV
        def parse_col(header, rows)
          return if rows == nil || header == nil
          result = []
          cols = []
          find_quote = false
          hsize = header.size

          add_col = lambda do |col|
            col.chomp!
            if col.start_with?("\"") && col.end_with?("\"")
              col = col.slice!(1..col.length - 2)
            end
            col.gsub!("\"\"", "\"")
            col.chomp!
            cols.push(col)
          end

          col = ""
          rows.each_char do |c|
            if c == "\""
              find_quote = !find_quote
            end

            if find_quote
              col << c
              next
            end

            if c == ","
              find_quote = false
              add_col.call(col)
              col = ""
            elsif c == "\n"
              col << c
              find_quote = false
              add_col.call(col)
              col = ""
              if cols.size < hsize
                cols.fill("", cols.size, hsize - cols.size)
              end
              result.push(cols)
              cols = []
            else
              col << c
            end
          end

          add_col.call(col) unless col.empty?
          unless cols.empty?
            if cols.size < hsize
              cols.fill("", cols.size, hsize - cols.size)
            end
            result.push(cols)
          end
          result
        end
      end
    end
  rescue Exception
  end

  # Fix 5: Run Langscore single-threaded (avoids Ruby 1.9.2 arm64 thread/Oniguruma races)
  begin
    if defined?(Langscore)
      class Window_Base
        def convert_escape_characters(text)
          if $langscore_current_language == Langscore::DEFAULT_LANGUAGE && Langscore::ENABLE_TRANSLATION_FOR_DEFLANG == false
            return ls_base_convert_escape_characters(text)
          end
          return ls_base_convert_escape_characters(text) if text.nil? || text.empty?

          key = text.chomp("\n")
          r0 = $ls_current_map ? Langscore.translate_for_map(key) : text
          r1 = Langscore.translate(key, $ls_troop_tr)
          r2 = Langscore.translate(key, $ls_common_event)

          found = nil
          found = r0 if r0 != key
          found = r1 if found.nil? && r1 != key
          found = r2 if found.nil? && r2 != key

          return ls_base_convert_escape_characters(text) if found.nil?
          ls_base_convert_escape_characters(found + "\n")
        end
      end

      class << DataManager
        def load_normal_database
          ls_base_load_normal_database
          if Langscore::ENABLE_PATCH_MODE
            Langscore.translate_list_reset()
          end
          $ls_graphics_tr ||= LSCSV.to_hash("Graphics")
          $ls_scripts_tr ||= LSCSV.to_hash("Scripts")
          $ls_troop_tr ||= LSCSV.to_hash("Troops")
          $ls_common_event ||= LSCSV.to_hash("CommonEvents")
          Langscore.changeLanguage($langscore_current_language, true)
        end
      end

      class << Langscore
        def changeLanguage(lang, force_update = false)
          return if force_update == false && $langscore_current_language == lang
          $langscore_current_language = lang
          Langscore.Translate_Script_Text
          Langscore.updateFont(lang)
          DataManager.ls_base_load_normal_database
          Langscore.updateSkills
          Langscore.updateClasses
          Langscore.updateStates
          Langscore.updateEnemies
          Langscore.updateItems
          Langscore.updateArmors
          Langscore.updateWeapons
          Langscore.updateSystem
          Langscore.updateActor
          $ls_graphic_cache ||= {}
          $ls_graphic_cache.clear
          GC.start
        end
      end
    end
  rescue Exception
  end
rescue Exception
end
