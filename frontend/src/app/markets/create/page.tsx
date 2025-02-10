'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import {createMarket} from "@/lib/api";

const CreateMarketForm: React.FC = () => {
  const [question, setQuestion] = useState('');
  const [outcomes, setOutcomes] = useState<string[]>(['']);
  const [endDate, setEndDate] = useState('');
  const [initialLiquidity, setInitialLiquidity] = useState('');
  const router = useRouter();

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();

    const marketData = {
      question,
      outcomes,
      endDate: new Date(endDate).getTime(),
      initialLiquidity
    };

    try {
      const response = await createMarket(marketData);
      console.log('Market created:', response.data);
      router.push('/markets');
    } catch (error) {
      console.error('Error creating market:', error);
    }
  };

  const handleOutcomeChange = (index: number, value: string) => {
    const newOutcomes = [...outcomes];
    newOutcomes[index] = value;
    setOutcomes(newOutcomes);
  };

  const addOutcome = () => {
    setOutcomes([...outcomes, '']);
  };

  const removeOutcome = (index: number) => {
    const newOutcomes = outcomes.filter((_, i) => i !== index);
    setOutcomes(newOutcomes);
  };

  return (
    <div className="max-w-7xl mx-auto py-12 px-4 sm:px-6 lg:px-8">
      <h1 className="text-3xl font-bold text-gray-900 mb-6">Create Market</h1>
      <form onSubmit={handleSubmit} className="space-y-6">
        <div>
          <label className="block text-sm font-medium text-gray-700">Question:</label>
          <input
            type="text"
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            required
            className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700">Outcomes:</label>
          {outcomes.map((outcome, index) => (
            <div key={index} className="flex items-center mb-2">
              <input
                type="text"
                value={outcome}
                onChange={(e) => handleOutcomeChange(index, e.target.value)}
                required
                className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
              />
              <button
                type="button"
                onClick={() => removeOutcome(index)}
                className="ml-2 px-3 py-1 bg-red-500 text-white rounded"
              >
                X
              </button>
            </div>
          ))}
          <button
            type="button"
            onClick={addOutcome}
            className="mt-2 px-4 py-2 bg-blue-500 text-white rounded"
          >
            Add Outcome
          </button>
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700">End Date:</label>
          <input
            type="date"
            value={endDate}
            onChange={(e) => setEndDate(e.target.value)}
            required
            className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700">Initial Liquidity:</label>
          <input
            type="text"
            value={initialLiquidity}
            onChange={(e) => setInitialLiquidity(e.target.value)}
            required
            className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
          />
        </div>
        <button
          type="submit"
          className="px-4 py-2 bg-blue-500 text-white rounded"
        >
          Create Market
        </button>
      </form>
    </div>
  );
};

export default CreateMarketForm;