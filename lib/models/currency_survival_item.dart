/// Models for US Currency recognition, ATM cash withdrawal, and financial survival.
///
/// STATUTORY CURRENCY COMPLIANCE (18 U.S.C. § 504 & 31 CFR Part 411):
/// All digital representations of United States currency are educational vector
/// illustrations that are one-sided, non-negotiable, and scaled to avoid any
/// resemblance to counterfeit currency under federal law.
library;

/// Category of currency or financial item.
enum CurrencyItemType {
  coin,
  banknote,
  atmStep,
  paystubField,
}

/// A US coin or paper bill item.
class CurrencyDenominationItem {
  final String id;
  final String name;
  final double valueDollars;
  final String displayValue;
  final CurrencyItemType type;
  final String visualEmoji;
  final String portraitOrSymbol;
  final String spokenDescription;
  final String practicalTip;

  const CurrencyDenominationItem({
    required this.id,
    required this.name,
    required this.valueDollars,
    required this.displayValue,
    required this.type,
    required this.visualEmoji,
    required this.portraitOrSymbol,
    required this.spokenDescription,
    required this.practicalTip,
  });
}

/// A step in the interactive audio ATM simulator.
class AtmSimulatorStep {
  final int stepNumber;
  final String actionTitle;
  final String iconEmoji;
  final String instruction;
  final String spokenGuidance;
  final String securityTip;

  const AtmSimulatorStep({
    required this.stepNumber,
    required this.actionTitle,
    required this.iconEmoji,
    required this.instruction,
    required this.spokenGuidance,
    required this.securityTip,
  });
}

/// Curated US currency denominations.
const List<CurrencyDenominationItem> officialCurrencyCatalog = [
  // --- Coins ---
  CurrencyDenominationItem(
    id: 'coin_penny',
    name: 'Penny (One Cent)',
    valueDollars: 0.01,
    displayValue: '1¢ / \$0.01',
    type: CurrencyItemType.coin,
    visualEmoji: '🪙',
    portraitOrSymbol: 'Abraham Lincoln • Copper color',
    spokenDescription:
        'Penny: Worth one cent. It is copper colored with President Abraham Lincoln on the front.',
    practicalTip: '100 pennies make one dollar.',
  ),
  CurrencyDenominationItem(
    id: 'coin_nickel',
    name: 'Nickel (Five Cents)',
    valueDollars: 0.05,
    displayValue: '5¢ / \$0.05',
    type: CurrencyItemType.coin,
    visualEmoji: '🪙',
    portraitOrSymbol: 'Thomas Jefferson • Silver, smooth edge',
    spokenDescription:
        'Nickel: Worth five cents. It is silver colored, thicker than a penny, with a smooth rim.',
    practicalTip: '20 nickels make one dollar. 5 pennies make one nickel.',
  ),
  CurrencyDenominationItem(
    id: 'coin_dime',
    name: 'Dime (Ten Cents)',
    valueDollars: 0.10,
    displayValue: '10¢ / \$0.10',
    type: CurrencyItemType.coin,
    visualEmoji: '🪙',
    portraitOrSymbol: 'Franklin D. Roosevelt • Smallest coin',
    spokenDescription:
        'Dime: Worth ten cents. It is the smallest and thinnest US coin, with ridges along the edge.',
    practicalTip: '10 dimes make one dollar. 2 nickels make one dime.',
  ),
  CurrencyDenominationItem(
    id: 'coin_quarter',
    name: 'Quarter (Twenty-Five Cents)',
    valueDollars: 0.25,
    displayValue: '25¢ / \$0.25',
    type: CurrencyItemType.coin,
    visualEmoji: '🪙',
    portraitOrSymbol: 'George Washington • Larger silver coin',
    spokenDescription:
        'Quarter: Worth twenty-five cents. It has President George Washington and ridges on the edge.',
    practicalTip: 'Four quarters make one dollar. Often used for laundry and parking meters.',
  ),

  // --- Banknotes ---
  CurrencyDenominationItem(
    id: 'bill_1',
    name: 'One Dollar Bill',
    valueDollars: 1.00,
    displayValue: '\$1',
    type: CurrencyItemType.banknote,
    visualEmoji: '💵',
    portraitOrSymbol: 'George Washington • The Great Seal',
    spokenDescription:
        'One dollar bill: Has George Washington in the center with large green numerals 1 in all four corners.',
    practicalTip: 'Check the numbers in the four corners to make sure it is a 1.',
  ),
  CurrencyDenominationItem(
    id: 'bill_5',
    name: 'Five Dollar Bill',
    valueDollars: 5.00,
    displayValue: '\$5',
    type: CurrencyItemType.banknote,
    visualEmoji: '💵',
    portraitOrSymbol: 'Abraham Lincoln • Lincoln Memorial',
    spokenDescription:
        'Five dollar bill: Features Abraham Lincoln with a large purple numeral 5 on the back.',
    practicalTip: 'Five single dollars equal one five dollar bill.',
  ),
  CurrencyDenominationItem(
    id: 'bill_10',
    name: 'Ten Dollar Bill',
    valueDollars: 10.00,
    displayValue: '\$10',
    type: CurrencyItemType.banknote,
    visualEmoji: '💵',
    portraitOrSymbol: 'Alexander Hamilton • US Treasury',
    spokenDescription:
        'Ten dollar bill: Features Alexander Hamilton with a large torch in the background.',
    practicalTip: 'Two five dollar bills equal one ten dollar bill.',
  ),
  CurrencyDenominationItem(
    id: 'bill_20',
    name: 'Twenty Dollar Bill',
    valueDollars: 20.00,
    displayValue: '\$20',
    type: CurrencyItemType.banknote,
    visualEmoji: '💵',
    portraitOrSymbol: 'Andrew Jackson • White House',
    spokenDescription:
        'Twenty dollar bill: Features Andrew Jackson. This is the most common bill given out by ATM cash machines.',
    practicalTip: 'When you take money from an ATM, you will usually receive twenty dollar bills.',
  ),
  CurrencyDenominationItem(
    id: 'bill_50',
    name: 'Fifty Dollar Bill',
    valueDollars: 50.00,
    displayValue: '\$50',
    type: CurrencyItemType.banknote,
    visualEmoji: '💵',
    portraitOrSymbol: 'Ulysses S. Grant • US Capitol',
    spokenDescription:
        'Fifty dollar bill: Features Ulysses S. Grant with subtle blue and red colors in the background.',
    practicalTip: 'Equal to two twenty dollar bills and one ten dollar bill.',
  ),
  CurrencyDenominationItem(
    id: 'bill_100',
    name: 'One Hundred Dollar Bill',
    valueDollars: 100.00,
    displayValue: '\$100',
    type: CurrencyItemType.banknote,
    visualEmoji: '💵',
    portraitOrSymbol: 'Benjamin Franklin • Independence Hall',
    spokenDescription:
        'One hundred dollar bill: Features Benjamin Franklin with a shiny blue 3D ribbon and copper bell.',
    practicalTip: 'Many small stores do not accept one hundred dollar bills for small purchases.',
  ),
];

/// Step-by-step ATM cash withdrawal simulator sequence.
const List<AtmSimulatorStep> officialAtmSteps = [
  AtmSimulatorStep(
    stepNumber: 1,
    actionTitle: 'Insert Debit Card',
    iconEmoji: '💳',
    instruction: 'Insert your debit card into the slot with the gold chip facing forward and up.',
    spokenGuidance:
        'Step 1: Insert your debit card into the slot. Make sure the gold chip points forward into the machine.',
    securityTip: 'Check the card slot: Never use an ATM if the card reader feels loose or suspicious.',
  ),
  AtmSimulatorStep(
    stepNumber: 2,
    actionTitle: 'Enter 4-Digit PIN',
    iconEmoji: '🔢',
    instruction: 'Type your 4-digit secret PIN on the keypad. Cover your hand while typing.',
    spokenGuidance:
        'Step 2: Enter your 4-digit secret PIN code on the keypad. Shield the keypad with your other hand.',
    securityTip: 'Never share your PIN with anyone, not even someone offering to help.',
  ),
  AtmSimulatorStep(
    stepNumber: 3,
    actionTitle: 'Select "Withdraw Cash"',
    iconEmoji: '🏧',
    instruction: 'Tap "Withdraw Cash" and choose "Checking Account".',
    spokenGuidance:
        'Step 3: On the screen, tap "Withdraw Cash", then select your "Checking Account".',
    securityTip: 'Take your time reading each screen option.',
  ),
  AtmSimulatorStep(
    stepNumber: 4,
    actionTitle: 'Choose Dollar Amount',
    iconEmoji: '💵',
    instruction: 'Select how much cash you want to withdraw (e.g. \$20, \$40, \$60, or \$100).',
    spokenGuidance:
        'Step 4: Select the amount of cash you want to take out. Most ATMs dispense twenty dollar bills.',
    securityTip: 'Only withdraw what you need to avoid carrying large sums of cash.',
  ),
  AtmSimulatorStep(
    stepNumber: 5,
    actionTitle: 'Take Your Cash Promptly',
    iconEmoji: '💰',
    instruction: 'Take your money from the dispenser slot immediately before it beeps.',
    spokenGuidance:
        'Step 5: The dispenser will open and count your bills. Grab your cash immediately and put it in your wallet.',
    securityTip: 'Put cash in your wallet or pocket before walking away from the machine.',
  ),
  AtmSimulatorStep(
    stepNumber: 6,
    actionTitle: 'Take Your Card & Receipt',
    iconEmoji: '👋',
    instruction: 'Take your debit card when the machine beeps, and decide if you want a receipt.',
    spokenGuidance:
        'Step 6: Listen for the beep and pull your card out. Never leave your card behind in the machine.',
    securityTip: 'Always verify your card is back in your wallet before walking away.',
  ),
];
