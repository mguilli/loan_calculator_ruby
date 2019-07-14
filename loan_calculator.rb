# Loan calculator

require 'yaml'
CONFIG = YAML.load_file('config.yml')
MSG = CONFIG[:message]
BOX = CONFIG[:box_output]
ERR_MSG = CONFIG[:error_msg]
TERMS = %i[amount rate length payment].freeze

# **** Formatting methods
def loan_terms_string(loan)
  output = loan.keys.map do |term|
    value_str = loan[term] ? CONFIG[:format][term] % loan[term] : 'No Data'
    value_str = (BOX[term] + value_str).ljust(BOX[:padding])
    "|  #{value_str}  |"
  end
  output.join("\n  ")
end

def display_main_menu(loan, message)
  puts <<~HEREDOC
    ******** Welcome to Loan Calculator ********

      Enter (1,2,3,or 4) to update a loan term
      Prepend with 'c' to calulate a loan term
      Example: enter 'c4' to calculate payment

      ===============Loan Terms===============
      #{loan_terms_string(loan)}
      ========================================
                (Enter 'q' to quit)
    #{message.lines.map { |l| l.chomp.center(46) }.join("\n")}
    Please enter a selection:
  HEREDOC
end

# **** Calculation methods
def enough_data?(loan, term)
  loan.none? { |k, v| k != term && v.nil? }
end

def calc_amount(loan)
  rate = (loan[:rate] / 100) / 12
  amount = loan[:payment] / (rate / (1 - (1 + rate)**(-loan[:length])))
  amount.round(2)
end

def calc_payment(loan)
  rate = (loan[:rate] / 100) / 12
  payment = loan[:amount] * (rate / (1 - (1 + rate)**(-loan[:length])))
  payment.round(2)
end

def calc_length(loan)
  rate = (loan[:rate] / 100) / 12
  numerator = -Math.log(1 - rate * loan[:amount] / loan[:payment])
  length = (numerator / Math.log(1 + rate)).ceil(2)
  length.round(2)
end

def calc_rate(loan)
  amt, length, pmt = %i[amount length payment].map { |key| loan[key] }
  rate = (100.00 / 100) / 12 # APR intial guess

  # Newton-Rhapson iterative method to find monthly interest to 6 decimal places
  loop do
    numerator = (pmt - (pmt * (1 + rate)**-length) - (rate * amt))
    denominator = (length * pmt * (1 + rate)**(-length - 1)) - amt
    new_rate = rate - (numerator / denominator)

    break if new_rate.round(6) == rate.round(6)

    rate = new_rate
  end

  rate.round(6).positive? ? (rate * 12 * 100).round(6) : nil
end

def calculate_loan(loan, term)
  method("calc_#{term}".to_sym).call(loan)
end

# **** Main program methods
def get_term_value(term)
  loop do
    puts CONFIG[:input_msg][term]
    print MSG[:prompt]
    value = gets.chomp

    break(value.to_f) if valid_data?(value, term)

    puts ERR_MSG[:invalid_data]
  end
end

def valid_data?(value, term)
  re = CONFIG[:regex][term]
  re =~ value && value.to_f.positive?
end

# ===== Main program start =====

loan = TERMS.map { |t| [t, nil] }.to_h
message = ''

loop do
  system('clear') || system('cls') # wipe_screen

  display_main_menu(loan, message)
  print MSG[:prompt]
  selection = gets.chomp

  case selection
  when /^q/i # Quit program
    puts MSG[:exit].center(BOX[:terminal_width], '*')
    break
  when /^[1-4]$/ # Data entry
    term = TERMS[selection.to_i - 1]
    loan[term] = get_term_value(term)
    message = "The loan #{term} has been updated!"
    message << ERR_MSG[:recalc] if enough_data?(loan, term)
  when /^c[1-4]$/i
    term = TERMS[selection[-1].to_i - 1]
    next(message = ERR_MSG[:not_enough_data]) unless enough_data?(loan, term)

    calculated_value = calculate_loan(loan, term)
    next(message = ERR_MSG[:rate_error]) unless calculated_value

    loan[term] = calculated_value
    message = "The loan #{term} has been calculated!"
  else
    message = ERR_MSG[:invalid_selection]
  end
end
