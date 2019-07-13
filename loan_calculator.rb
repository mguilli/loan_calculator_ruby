# Loan calculator
require 'yaml'
CONFIG = YAML.load_file('config.yml')
MSG = CONFIG[:message]
BOX = CONFIG[:box_output]
ERR_MSG = CONFIG[:error_msg]
terms = %i[amount rate length payment]

# **** Formatting methods
def center(str, pad_char = ' ', width = BOX[:terminal_width])
  str.lines.map { |line| line.strip.center(width, pad_char) }.join("\n")
end

def box_ends(msg, str, char)
  indent = BOX[:indent]
  msg << char.ljust(indent)
  msg << str.ljust(BOX[:width] - (indent + 1))
  msg << char + "\n"
end

def display_loan_terms(loan)
  msg = center(BOX[:title], '=', BOX[:width]) + "\n"

  loan.keys.each do |term|
    value_str = loan[term] ? CONFIG[:format][term] % loan[term] : 'No Data'
    box_ends(msg, BOX[term] + value_str, '|')
  end

  msg << center('=', '=', BOX[:width]) + "\n" + BOX[:quit]
  msg
end

def wipe_screen
  system('cls') || system('clear')
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

loan = terms.map { |t| [t, nil] }.to_h
continue = true
message = ''

while continue
  wipe_screen
  puts center(MSG[:title], '*') + "\n\n"
  puts center(MSG[:instructions])
  puts center(display_loan_terms(loan))
  puts center(message)
  # Prompt user for menu selection
  puts MSG[:prompt_msg]
  print MSG[:prompt]
  selection = gets.chomp

  case selection
  when /^q/i # Quit program
    puts center(MSG[:exit], '*')
    continue = false
  when /^[1-4]$/ # Data entry
    term = terms[selection.to_i - 1]
    loan[term] = get_term_value(term)
    message = "The loan #{term} has been updated!"
    message << ERR_MSG[:recalc] if enough_data?(loan, term)
  when /^c[1-4]$/i
    term = terms[selection[-1].to_i - 1]
    next(message = ERR_MSG[:not_enough_data]) unless enough_data?(loan, term)

    calculated_value = calculate_loan(loan, term)
    next(message = ERR_MSG[:rate_error]) unless calculated_value

    loan[term] = calculated_value
    message = "The loan #{term} has been calculated!"
  else
    message = ERR_MSG[:invalid_selection]
  end
end
