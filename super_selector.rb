require 'open-uri'
require 'rubygems'
require 'nokogiri'
require 'active_support'
require 'active_support/core_ext'
require 'yaml'
require 'colorize'

class FantasyInnings
	attr_accessor :batting_records, :our_team_batting_total, :our_team_bowling_total, :our_team_fielding_total, 
	:opposing_team_batting_total, :opposing_team_bowling_total, :opposing_team_fielding_total, 
	:player_batting_score, :player_bowling_score, :player_fielding_score, :our_team_total, :opposing_team_total

	def initialize(batting_card)
		@batting_records = batting_card.css(".flex-row").css(".wrap.batsmen")

		@our_team_batting_total = 0
		@opposing_team_batting_total = 0
		@our_team_bowling_total = 0
		@our_team_total = 0

		@opposing_team_bowling_total = 0
		@our_team_fielding_total = 0
		@opposing_team_fielding_total = 0
		@opposing_team_total = 0

		@player_batting_score = Hash.new(0)
		@player_bowling_score = Hash.new(0)
		@player_fielding_score = Hash.new(0)
	end

	def aggregate(players)
		dismissal_infos = get_dismissal_infos(players)

		dismissal_infos.each do |dismissal|
			if ((dismissal.include? 'st ') || (dismissal.include? 'c '))
				update_scores_for_catch_or_stumping(dismissal)			
				next;
			elsif (dismissal.include? 'run out')
				update_scores_for_runout(dismissal)
				next
			elsif ((dismissal.include? 'lbw ')	|| (dismissal.include? 'b '))
				update_scores_for_lbw_or_bowled(dismissal)
			end
		end

		add_bonus_points(FantasyInnings::OUR_TEAM)
		add_bonus_points(FantasyInnings::OPPOSING_TEAM, false)

		puts "Our Team Bowling Score : " + @our_team_bowling_total.to_s
		puts "Opposing Team Bowling Score : " + @opposing_team_bowling_total.to_s
		puts "Our Team Fielding Score : " + @our_team_fielding_total.to_s
		puts "Opposing Team Fielding Score : " + @opposing_team_fielding_total.to_s
		@our_team_total = @our_team_batting_total + @our_team_bowling_total + @our_team_fielding_total
		@opposing_team_total = @opposing_team_batting_total + @opposing_team_bowling_total + @opposing_team_fielding_total
		return @our_team_total - @opposing_team_total
	end

	private 

	def add_bonus_points(players, our_team = true)
		players.each do |player_name|
			add_bonus_points_for_wickets(player_name, our_team)	
			add_bonus_points_for_batsmen(player_name, our_team)	
		end	
	end	

	def add_bonus_points_for_wickets(player_name, our_team)
		captain = our_team ? FantasyInnings::OUR_CAPTAIN : FantasyInnings::OPPONENT_CAPTAIN
		is_player_captain = captain.include?(player_name)
		player_score = is_player_captain ? @player_bowling_score[player_name]/2 : @player_bowling_score[player_name]
		wickets = player_score/20

		points = 0
		if wickets.between?(2,3)
			points = is_player_captain ? 2*10 : 10
		elsif wickets == 4
			points = is_player_captain ? 2*25 : 25
		elsif wickets >= 5
			points = is_player_captain ? 2*50 : 50
		end		

		if our_team
			@our_team_bowling_total += points
		else
			@opposing_team_bowling_total += points	
		end
		@player_bowling_score[player_name] += points
	end	

	def add_bonus_points_for_batsmen(player_name, our_team)
		captain = our_team ? FantasyInnings::OUR_CAPTAIN : FantasyInnings::OPPONENT_CAPTAIN
		is_player_captain = captain.include?(player_name)
		player_score = is_player_captain ? @player_batting_score[player_name]/2 : @player_batting_score[player_name]
		milestone = player_score/50

		points = 0
		if milestone == 1
			points = is_player_captain ? 2*10 : 10
		elsif milestone == 2
			points = is_player_captain ? 2*25 : 25
		elsif milestone >= 3
			points = is_player_captain ? 2*50 : 50
		end

		if our_team
			@our_team_batting_total += points
		else
			@opposing_team_batting_total += points	
		end	
		@player_batting_score[player_name] += points		
	end	

	def get_dismissal_infos(players)
		dismissal_infos = []
		
		@batting_records.each do |batting_record|
			batsman_name = batting_record.css(".cell.batsmen").css("a").text
			runs = batting_record.css(".cell.runs")[0].text.to_i

			if (players.include? batsman_name) 			
				if (OUR_CAPTAIN.include? batsman_name)
					@our_team_batting_total += 2*runs
					@player_batting_score[batsman_name] = 2*runs
				else	
					@our_team_batting_total += runs
					@player_batting_score[batsman_name] = runs
				end
			elsif (OPPOSING_TEAM.include? batsman_name)
				if (OPPONENT_CAPTAIN.include? batsman_name)
					@opposing_team_batting_total += 2*runs
					@player_batting_score[batsman_name] = 2*runs
				else	
					@opposing_team_batting_total += runs
					@player_batting_score[batsman_name] = runs
				end
			end

			dismissal = batting_record.css(".cell.commentary").css("a").text
			dismissal.strip!
			dismissal_infos << dismissal
		end

		puts "Our team batting score: " + @our_team_batting_total.to_s
		puts "Opposing team batting score: " + @opposing_team_batting_total.to_s

		dismissal_infos
	end	

	def update_scores_for_catch_or_stumping(dismissal)
		involved_players = dismissal.split(' b ')

		fielder_name = involved_players[0]
		fielder_name.gsub!(/†/, '')  # Doing this for keepers where you have † symbol.

		if (fielder_name.include? '&') 
			fielder_name = dismissal.split(' & ').last
		elsif (fielder_name.include? 'c ')
			fielder_name = fielder_name.split('c ').last
		elsif (fielder_name.include? 'st ')	
			fielder_name = fielder_name.split('st ').last
		end

		update_score_for_fielder(fielder_name)

		bowler_name = involved_players[1]
		update_score_for_bowler(bowler_name, 20)
	end

	def update_scores_for_lbw_or_bowled(dismissal)
		bowler_name = dismissal.split('b ')[1]
		update_score_for_bowler(bowler_name, 25)
	end

	def update_score_for_bowler(bowler_name, points)
		if (bowler_name != nil)
			opposing_team_bowler_name = OPPOSING_TEAM.find {|s| s.include? bowler_name}
			if (opposing_team_bowler_name != nil)
				if (OPPONENT_CAPTAIN.include? bowler_name)
					@opposing_team_bowling_total += 2*points
					@player_bowling_score[opposing_team_bowler_name] += 2*points
				else
					@opposing_team_bowling_total += points
					@player_bowling_score[opposing_team_bowler_name] += points
				end
			else
				our_team_bowler_name = OUR_TEAM.find {|s| s.include? bowler_name}
				if (OUR_CAPTAIN.include? bowler_name)
					@our_team_bowling_total += 2*points
					@player_bowling_score[our_team_bowler_name] += 2*points
				else
					@our_team_bowling_total += points
					@player_bowling_score[our_team_bowler_name] += points
				end
			end
		end
	end	

	def update_scores_for_runout(dismissal)
		fielder_name = dismissal.scan(/\((.*)\)/)[0][0]
		if(fielder_name.include? '/')
			fielder_names = fielder_name.split('/')
			fielder_names.each do |fn|
				fn.gsub!(/†/, '')  # Doing this for keepers where you have † symbol.
				update_score_for_fielder(fn, true)
			end
			return
		end

		update_score_for_fielder(fielder_name)
	end

	def update_score_for_fielder(fielder_name, split = false)
		opposing_team_fielder_name = OPPOSING_TEAM.find {|s| s.include? fielder_name}
		fielding_points = split ? 2.5 : 5
		if (opposing_team_fielder_name != nil)
			if (OPPONENT_CAPTAIN.include? opposing_team_fielder_name)
				@opposing_team_fielding_total += 2*fielding_points
				@player_fielding_score[opposing_team_fielder_name] += 2*fielding_points
			else
				@opposing_team_fielding_total += fielding_points
				@player_fielding_score[opposing_team_fielder_name] += fielding_points
			end
		else
			our_team_fielder_name = OUR_TEAM.find {|s| s.include? fielder_name}
			if (our_team_fielder_name != nil)			
				if (OUR_CAPTAIN.include? our_team_fielder_name)
					@our_team_fielding_total += 2*fielding_points
					@player_fielding_score[our_team_fielder_name] += 2*fielding_points
				else
					@our_team_fielding_total += fielding_points
					@player_fielding_score[our_team_fielder_name] += fielding_points
				end
			end
		end
	end
end

class Team
	attr_accessor :players, :power_player, :scorecard

	def initialize(team, scorecard)
		@players = team[:players].split(', ')
		@power_player = team[:power_player]
		@scorecard = scorecard
	end	

	def total
		fi = first_innings_total
		si = second_innings_total

		puts "*"*100

		printf "%-20s %-20s %-20s %-20s %-20s\n", "Player", "Batting Score", "Bowling Score", "Fielding Score", "Total Score"
		player_final_batting_score = Hash.new(0)
		player_final_bowling_score = Hash.new(0)
		player_final_fielding_score = Hash.new(0)
		player_final_score = Hash.new(0)

		@players.each do |player|
			player_final_batting_score[player] = fi.player_batting_score[player] + si.player_batting_score[player]
			player_final_bowling_score[player] = fi.player_bowling_score[player] + si.player_bowling_score[player]
			player_final_fielding_score[player] = fi.player_fielding_score[player] + si.player_fielding_score[player]

			player_final_score[player] = player_final_batting_score[player] + player_final_bowling_score[player] + player_final_fielding_score[player]
			
			player_name = (@power_player.include? player) ? player.strip + "*" : player.strip
			printf "%-20s %-20s %-20s %-20s %-20s\n", player_name, player_final_batting_score[player].to_s, player_final_bowling_score[player].to_s, player_final_fielding_score[player].to_s, player_final_score[player].to_s
		end

	end	

	private 

	def first_innings_total
		puts "FIRST INNINGS: ".colorize(:color => :white, :background => :black).bold
		first_innings = FantasyInnings.new(@scorecard[0])
		puts "First Innings Aggregate : ".bold + first_innings.aggregate.to_s

		first_innings
	end
	
	def second_innings_total
		puts "SECOND INNINGS: ".colorize(:color => :white, :background => :black).bold
		second_innings = FantasyInnings.new(@scorecard[2])
		puts "Second Innings Aggregate : ".bold + second_innings.aggregate.to_s

		second_innings
	end	
end	

game_config = YAML.load(ERB.new(File.read('game_config.yml')).result).deep_symbolize_keys
page = Nokogiri::HTML(open(game_config[:game][:match_url]).read)

our_team = Team.new(game_config[:our_team], page.css(".scorecard-section"))
opposing_team = Team.new(game_config[:opposing_team], page.css(".scorecard-section"))
our_team.total
opposing_team.total

# final_game_total = our_team.total - opposing_team.total
# puts "MATCH AGGREGATE : ".bold + ((final_game_total < 0) ? final_game_total.to_s.red : final_game_total.to_s.green)

mom_div = page.css(".match-detail-container").css(".match-detail--item")[2].css(".match-detail--right")
if (mom_div != nil)
	man_of_the_match = mom_div.text
	puts 'MAN OF THE MATCH: '.bold + man_of_the_match.to_s
	# if (FantasyInnings::OUR_TEAM.include? man_of_the_match) 			
	# 	if (FantasyInnings::OUR_CAPTAIN.include? man_of_the_match)
	# 		first_innings.our_team_batting_total += 2*30
	# 		first_innings.player_batting_score[man_of_the_match] = 2*30
	# 	else	
	# 		first_innings.our_team_batting_total += 30
	# 		first_innings.player_batting_score[man_of_the_match] = 30
	# 	end
	# elsif (FantasyInnings::OPPOSING_TEAM.include? man_of_the_match)
	# 	if (FantasyInnings::OPPONENT_CAPTAIN.include? man_of_the_match)
	# 		first_innings.opposing_team_batting_total += 2*runs
	# 		first_innings.player_batting_score[man_of_the_match] = 2*runs
	# 	else	
	# 		first_innings.opposing_team_batting_total += runs
	# 		first_innings.player_batting_score[man_of_the_match] = runs
	# 	end
	# end
end

# if (FantasyInnings::OUR_TEAM.include? man_of_the_match)
# 	match_aggregate = final_total + 50
# else
# 	match_aggregate = final_total - 50
# end
# puts "MATCH AGGREGATE : ".bold + ((match_aggregate < 0) ? match_aggregate.to_s.red : match_aggregate.to_s.green)

# Writing to a spreadsheet
# book = Spreadsheet::Workbook.new 
# sheet1 = book.create_worksheet :name => "game_points"

# sheet1[0,0] = "Player"
# sheet1[0,1] = "Batting Score"
# sheet1[0,2] = "Bowling Score"
# sheet1[0,3] = "Total Score"

# book.write 'fantasy_points.xls'
