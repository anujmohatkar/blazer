require 'json'
require 'sanitize'
module Blazer
    class Podcard
        def initialize(rows, columns)
            @rows = rows
            @columns = columns
        end

        def array
            podcast_array = []
            @rows. each do |row|
                podcast = Podcast.new(row, @columns)
                podcast_array << podcast
            end
            podcast_array
        end  
    end

    class Podcast
        def initialize(rows, columns)
            @rows = rows
            @columns = columns
        end

        def tests
            "#{@rows.length} hello #{@columns.length}"
        end

        def index(param)
            index = 0 
            @columns.each do |column|
                if column == param
                    return index
                end
                index += 1
            end
            return -1
        end

        def param_check(param)
            index = index("#{param}")
            if index == -1
                return "No #{param}"
            end
            return @rows[index]
        end

        def title
            param_check("title")
        end

        def summary
            Sanitize.fragment(param_check("summary"))
        end


        def transcript
            param_check("transcript")
        end

        def audio_url
            param_check("audio_url")
        end

        def published_time
            time = param_check("published_time")
            return time.to_formatted_s(:long_ordinal)
        end

        def audio_s3_location
            param_check("audio_s3_location")
        end

        def audio_type
            param_check("audio_type")
        end

        def speaker_names # change it speakerNames
            names = JSON.parse(param_check("speaker_names")) # change it speakerNames
            speakers = String.new
            names.each do |name|
                speakers += "#{name}, "
            end
            return speakers
        end

        def transcript_entities
            transcript_entities = JSON.parse(param_check("transcript_entities"))
            return transcript_entities
        end

        def source_feed
            param_check("source_feed")
        end

    end
end